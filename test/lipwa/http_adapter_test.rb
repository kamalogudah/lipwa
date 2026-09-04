# frozen_string_literal: true

require "test_helper"
require "stringio"

class HttpAdapterTest < Minitest::Test
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

  def test_timeout_and_open_timeout_are_configured_on_the_connection
    adapter = Lipwa::HttpAdapter.new(base_url: "https://example.com", timeout: 7, open_timeout: 2)

    assert_equal 7, adapter.timeout
    assert_equal 2, adapter.open_timeout
  end
end
