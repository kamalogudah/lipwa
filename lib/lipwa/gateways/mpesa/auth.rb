# frozen_string_literal: true

require "base64"
require_relative "../../errors"
require_relative "../../http_adapter"

module Lipwa
  module Gateways
    class Mpesa
      # OAuth2 client-credentials token acquisition + caching for
      # Safaricom Daraja. Exposes #call so an instance can be handed
      # directly to Lipwa::AuthStrategies::BearerToken as its
      # token_provider: the STK Push/C2B/B2C HttpAdapter calls #call on
      # every request, and gets back a cached token until it's close to
      # expiring, at which point a fresh one is fetched transparently.
      #
      # The token endpoint itself authenticates with HTTP Basic auth
      # (consumer_key:consumer_secret) rather than a bearer token, so
      # this class talks to it directly instead of going through
      # AuthStrategies.
      class Auth
        BASE_URLS = {
          sandbox: "https://sandbox.safaricom.co.ke",
          production: "https://api.safaricom.co.ke"
        }.freeze

        OAUTH_PATH = "/oauth/v1/generate"

        # Refresh this many seconds before the token's reported expiry,
        # so a request that starts just before expiry doesn't race a
        # token that goes stale mid-flight.
        EXPIRY_BUFFER = 60

        # rubocop:disable Metrics/ParameterLists
        def initialize(consumer_key:, consumer_secret:, env: :sandbox, base_url: nil, http: nil, clock: -> { Time.now })
          ensure_credentials_present!(consumer_key, consumer_secret)

          @consumer_key = consumer_key
          @consumer_secret = consumer_secret
          @clock = clock
          @http = http || Lipwa::HttpAdapter.new(base_url: base_url || base_url_for(env))
          @mutex = Mutex.new
          @token = nil
          @expires_at = nil
        end
        # rubocop:enable Metrics/ParameterLists

        # Returns a cached access token, or fetches (and caches) a new
        # one if there's none yet or the cached one is about to expire.
        # Safe to call concurrently: only one refresh happens in flight,
        # other callers block on it and reuse its result.
        def initialize_copy(source)
          super
          @token = nil
          @expires_at = nil
          @mutex = Mutex.new
          @http = Lipwa::HttpAdapter.new(base_url: @http.base_url, timeout: @http.timeout,
                                         open_timeout: @http.open_timeout, logger: @http.logger,
                                         adapter: @http.adapter)
        end

        def inspect
          "#<#{self.class}:0x#{object_id.to_s(16)}>"
        end

        def call
          return @token if fresh?

          @mutex.synchronize do
            refresh! unless fresh?
          end

          @token
        end

        private

        def fresh?
          @token && @expires_at && @clock.call < @expires_at
        end

        def refresh!
          response = @http.get(
            OAUTH_PATH,
            params: { grant_type: "client_credentials" },
            headers: { "Authorization" => "Basic #{encoded_credentials}" }
          )
          body = response.body

          @token = body.fetch("access_token")
          @expires_at = @clock.call + body.fetch("expires_in").to_i - EXPIRY_BUFFER
        rescue KeyError
          raise Lipwa::GatewayError.new("unexpected Daraja OAuth response: #{body.inspect}", raw: body)
        end

        def encoded_credentials
          Base64.strict_encode64("#{@consumer_key}:#{@consumer_secret}")
        end

        def base_url_for(env)
          BASE_URLS.fetch(env.to_sym) do
            raise Lipwa::ConfigurationError, "unknown M-Pesa env #{env.inspect} — must be :sandbox or :production"
          end
        end

        def ensure_credentials_present!(consumer_key, consumer_secret)
          return if consumer_key && consumer_secret

          raise Lipwa::ConfigurationError, "Mpesa::Auth requires both consumer_key and consumer_secret"
        end
      end
    end
  end
end
