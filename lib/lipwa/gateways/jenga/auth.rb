# frozen_string_literal: true

require "faraday"
require "json"
require "time"
require_relative "../../errors"

module Lipwa
  module Gateways
    class Jenga
      # Fetches and caches Jenga's merchant OAuth token.
      class Auth
        EXPIRY_BUFFER = 60

        def initialize(api_key:, merchant_code:, consumer_secret:, token_url:, clock: -> { Time.now })
          unless api_key && merchant_code && consumer_secret
            raise Lipwa::ConfigurationError,
                  "Jenga::Auth requires api_key, merchant_code, and consumer_secret"
          end

          @api_key = api_key
          @merchant_code = merchant_code
          @consumer_secret = consumer_secret
          @token_url = token_url
          @clock = clock
          @mutex = Mutex.new
        end

        def initialize_copy(source)
          super
          @token = nil
          @expires_at = nil
          @mutex = Mutex.new
        end

        def call
          return @token if fresh?

          @mutex.synchronize { refresh! unless fresh? }
          @token
        end

        private

        def fresh? = @token && @expires_at && @clock.call < @expires_at

        def refresh!
          response = Faraday.post(@token_url) do |request|
            request.headers["Api-Key"] = @api_key
            request.headers["Content-Type"] = "application/json"
            request.body = JSON.generate(merchantCode: @merchant_code, consumerSecret: @consumer_secret)
          end
          body = JSON.parse(response.body)
          unless response.success?
            raise Lipwa::GatewayError.new("Jenga OAuth failed", code: response.status.to_s, raw: body)
          end

          @token = body.fetch("accessToken")
          @expires_at = expiry_time(body.fetch("expiresIn", 900))
        rescue Faraday::Error, JSON::ParserError, KeyError, ArgumentError => e
          raise Lipwa::GatewayError.new("unexpected Jenga OAuth response: #{e.message}",
                                        raw: defined?(body) ? body : nil)
        end

        def expiry_time(value)
          expiry = value.is_a?(Numeric) || value.to_s.match?(/\A\d+\z/) ? @clock.call + value.to_i : Time.parse(value)
          expiry - EXPIRY_BUFFER
        end
      end
    end
  end
end
