# frozen_string_literal: true

require "bigdecimal"
require "faraday"
require "faraday/retry"
require "json"
require_relative "errors"
require_relative "auth_strategies"
require_relative "logging"

module Lipwa
  # Thin wrapper around Faraday shared by every gateway's HTTP calls:
  # retries with backoff, request/open timeouts, optional logging, and
  # a pluggable auth strategy (see Lipwa::AuthStrategies) so OAuth2
  # bearer tokens (M-Pesa, Co-op) and request-signing (Jenga) plug into
  # the same request path without HttpAdapter knowing which is which.
  class HttpAdapter
    IDEMPOTENCY_HEADER = "Idempotency-Key"
    RETRYABLE_METHODS = %i[get head options].freeze
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze
    RETRYABLE_EXCEPTIONS = Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS.freeze
    RETRY_IF_IDEMPOTENT = lambda do |env, _exception|
      value = env.request_headers[IDEMPOTENCY_HEADER]
      !value.nil? && !value.empty?
    end

    DEFAULT_RETRY_OPTIONS = {
      max: 2,
      interval: 0.5,
      interval_randomness: 0.5,
      backoff_factor: 2,
      max_interval: 5,
      retry_statuses: RETRYABLE_STATUSES,
      methods: RETRYABLE_METHODS,
      exceptions: RETRYABLE_EXCEPTIONS,
      retry_if: RETRY_IF_IDEMPOTENT
    }.freeze

    attr_reader :base_url, :auth_strategy, :timeout, :open_timeout, :logger, :adapter, :retry_options

    # rubocop:disable Metrics/ParameterLists
    def initialize(base_url:, auth_strategy: AuthStrategies::None.new, timeout: 10,
                   open_timeout: 5, logger: nil, retry_options: {}, stubs: nil,
                   adapter: Faraday.default_adapter)
      @base_url = base_url
      @auth_strategy = auth_strategy
      @timeout = timeout
      @open_timeout = open_timeout
      @logger = logger
      @retry_options = DEFAULT_RETRY_OPTIONS.merge(retry_options).freeze
      @stubs = stubs
      @adapter = adapter
    end
    # rubocop:enable Metrics/ParameterLists

    def get(path, params: {}, headers: {}, idempotency_key: nil)
      request(:get, path, params: params, headers: idempotency_headers(headers, idempotency_key))
    end

    def post(path, body: nil, params: {}, headers: {}, idempotency_key: nil)
      request(:post, path, body: body, params: params, headers: idempotency_headers(headers, idempotency_key))
    end

    def put(path, body: nil, params: {}, headers: {}, idempotency_key: nil)
      request(:put, path, body: body, params: params, headers: idempotency_headers(headers, idempotency_key))
    end

    # Auth strategies may own API keys or OAuth clients. Avoid recursively
    # exposing them through the adapter's default instance-variable dump.
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)}>"
    end

    private

    def request(method, path, params: {}, body: nil, headers: {})
      connection.public_send(method) { |req| build_request(req, path, params, body, headers) }
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise Lipwa::GatewayError.new("network error: #{e.message}", raw: e)
    rescue Faraday::Error => e
      raise Lipwa::GatewayError.new(e.message, code: e.response&.dig(:status)&.to_s, raw: e.response)
    end

    def build_request(req, path, params, body, headers)
      req.url(path)
      req.params.update(params) if params && !params.empty?
      req.headers.update(headers)
      req.body = json_safe_decimals(body) if body
    end

    def idempotency_headers(headers, idempotency_key)
      return headers unless idempotency_key

      headers.merge(IDEMPOTENCY_HEADER => idempotency_key)
    end

    # JSON otherwise encodes BigDecimal as a quoted scientific-notation string.
    # A fragment preserves the exact base-10 value as a JSON number.
    def json_safe_decimals(value)
      case value
      when BigDecimal
        JSON::Fragment.new(value.to_s("F"))
      when Hash
        value.transform_values { |item| json_safe_decimals(item) }
      when Array
        value.map { |item| json_safe_decimals(item) }
      else
        value
      end
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |conn|
        configure_middleware(conn)
        configure_timeouts(conn)
        @stubs ? conn.adapter(:test, @stubs) : conn.adapter(@adapter)
      end
    end

    def configure_middleware(conn)
      conn.request :retry, retry_options
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.use AuthMiddleware, auth_strategy
      configure_logger(conn) if logger
    end

    def configure_logger(conn)
      conn.use Logging::Middleware, logger
    end

    def configure_timeouts(conn)
      conn.options.timeout = timeout
      conn.options.open_timeout = open_timeout
    end

    # Applies the configured AuthStrategy on every outgoing request.
    class AuthMiddleware < Faraday::Middleware
      def initialize(app, auth_strategy)
        super(app)
        @auth_strategy = auth_strategy
      end

      def on_request(env)
        @auth_strategy.apply(env)
      end
    end
  end
end
