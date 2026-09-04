# frozen_string_literal: true

require "test_helper"
require "stringio"

class HttpAdapterTest < Minitest::Test
  CollectingLogger = Struct.new(:events) do
    def info(event) = events << [:info, event]
    def error(event) = events << [:error, event]
  end

  def test_get_returns_parsed_json_body
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/ping") { [200, { "Content-Type" => "application/json" }, '{"ok":true}'] }
    end
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", stubs: stubs)

    response = adapter.get("/ping")

    assert_equal({ "ok" => true }, response.body)
    stubs.verify_stubbed_calls
  end

  def test_post_sends_json_body
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/things") do |env|
        assert_equal '{"name":"lipwa"}', env.body
        [201, {}, ""]
      end
    end
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", stubs: stubs)

    response = adapter.post("/things", body: { name: "lipwa" })

    assert_equal 201, response.status
    stubs.verify_stubbed_calls
  end

  def test_post_serializes_big_decimals_as_exact_json_numbers
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/amounts") do |env|
        assert_equal({ "amount" => BigDecimal("10.25") },
                     JSON.parse(env.body, decimal_class: BigDecimal))
        [201, {}, ""]
      end
    end
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", stubs: stubs)

    adapter.post("/amounts", body: { amount: BigDecimal("10.25") })

    stubs.verify_stubbed_calls
  end

  def test_sends_idempotency_key_header
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/payments") do |env|
        assert_equal "payment-123", env.request_headers["Idempotency-Key"]
        [200, {}, ""]
      end
    end
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", stubs: stubs)

    adapter.post("/payments", idempotency_key: "payment-123")

    stubs.verify_stubbed_calls
  end

  def test_auth_strategy_is_applied_to_every_request
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/secure") do |env|
        assert_equal "Bearer token-123", env.request_headers["Authorization"]
        [200, {}, ""]
      end
    end
    auth = Lipwa::AuthStrategies::BearerToken.new(-> { "token-123" })
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", auth_strategy: auth, stubs: stubs)

    adapter.get("/secure")

    stubs.verify_stubbed_calls
  end

  def test_none_auth_strategy_adds_no_authorization_header
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/open") do |env|
        assert_nil env.request_headers["Authorization"]
        [200, {}, ""]
      end
    end
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", stubs: stubs)

    adapter.get("/open")

    stubs.verify_stubbed_calls
  end

  def test_retries_on_5xx_up_to_the_configured_max
    attempts = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/flaky") do |env|
        assert_equal "retry-123", env.request_headers["Idempotency-Key"]
        attempts += 1
        attempts < 3 ? [503, {}, ""] : [200, {}, "ok"]
      end
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com",
      stubs: stubs,
      retry_options: { max: 2, interval: 0 }
    )

    response = adapter.get("/flaky", idempotency_key: "retry-123")

    assert_equal 200, response.status
    assert_equal 3, attempts
  end

  def test_retries_post_with_an_idempotency_key
    attempts = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/payments") do
        attempts += 1
        attempts < 2 ? [503, {}, ""] : [200, {}, "ok"]
      end
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com", stubs: stubs,
      retry_options: { interval: 0 }
    )

    response = adapter.post("/payments", idempotency_key: "payment-123")

    assert_equal 200, response.status
    assert_equal 2, attempts
  end

  def test_does_not_retry_post_without_an_idempotency_key
    attempts = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/payments") do
        attempts += 1
        [503, {}, ""]
      end
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com", stubs: stubs,
      retry_options: { interval: 0 }
    )

    response = adapter.post("/payments")

    assert_equal 503, response.status
    assert_equal 1, attempts
  end

  def test_retry_after_header_takes_precedence_over_exponential_backoff
    waits = []
    attempts = 0
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/limited") do
        attempts += 1
        attempts < 2 ? [429, { "Retry-After" => "1.25" }, ""] : [200, {}, "ok"]
      end
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com", stubs: stubs,
      retry_options: {
        max: 1, interval: 0,
        retry_block: ->(will_retry_in:, **) { waits << will_retry_in }
      }
    )

    response = adapter.get("/limited")

    assert_equal 200, response.status
    assert_equal [1.25], waits
  end

  def test_retry_policy_has_bounded_exponential_backoff
    options = Lipwa::HttpAdapter::DEFAULT_RETRY_OPTIONS

    assert_equal 2, options[:max]
    assert_equal 0.5, options[:interval]
    assert_equal 0.5, options[:interval_randomness]
    assert_equal 2, options[:backoff_factor]
    assert_equal 5, options[:max_interval]
    assert_equal %i[get head options], options[:methods]
    assert_equal [429, 500, 502, 503, 504], options[:retry_statuses]
  end

  def test_network_error_is_wrapped_in_gateway_error
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/down") { raise Faraday::ConnectionFailed, "connection refused" }
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com",
      stubs: stubs,
      retry_options: { max: 0 }
    )

    error = assert_raises(Lipwa::GatewayError) { adapter.get("/down") }
    assert_match(/connection refused/, error.message)
  end

  def test_logger_redacts_authorization_header
    io = StringIO.new
    logger = Logger.new(io)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/secure") { [200, {}, ""] }
    end
    auth = Lipwa::AuthStrategies::BearerToken.new(-> { "super-secret-token" })
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com",
      auth_strategy: auth,
      logger: logger,
      stubs: stubs
    )

    adapter.get("/secure")

    refute_match(/super-secret-token/, io.string)
  end

  def test_logger_emits_structured_redacted_event
    logger = CollectingLogger.new([])
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/payments") do
        [200, { "Content-Type" => "application/json", "Set-Cookie" => "token=response-secret" },
         '{"access_token":"response-secret","reference":"payment-1"}']
      end
    end
    adapter = Lipwa::HttpAdapter.new(
      base_url: "https://example.com", logger: logger, stubs: stubs,
      auth_strategy: Lipwa::AuthStrategies::BearerToken.new(-> { "header-secret" })
    )

    adapter.post("/payments", params: { token: "query-secret" },
                              body: { password: "body-secret", amount: 100 })

    level, event = logger.events.fetch(0)
    assert_equal :info, level
    assert_equal "lipwa.http", event[:event]
    assert_equal "POST", event[:method]
    assert_equal 200, event[:status]
    assert_kind_of Numeric, event[:duration_ms]
    assert_equal "[REDACTED]", event.dig(:request, :headers, "Authorization")
    assert_equal "[REDACTED]", event.dig(:response, :body, "access_token")
    assert_equal "payment-1", event.dig(:response, :body, "reference")
    refute_match(/header-secret|query-secret|body-secret|response-secret/, event.inspect)
  end

  def test_timeout_and_open_timeout_are_configured_on_the_connection
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", timeout: 7, open_timeout: 2)

    assert_equal 7, adapter.timeout
    assert_equal 2, adapter.open_timeout
  end
end
