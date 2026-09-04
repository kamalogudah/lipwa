# frozen_string_literal: true

require "faraday"
require "json"
require_relative "../../errors"

module Lipwa
  module Gateways
    class Pesapal
      # Fetches and briefly caches Pesapal API bearer tokens.
      class Auth
        TOKEN_PATH = "/api/Auth/RequestToken"

        def initialize(consumer_key:, consumer_secret:, base_url:, clock: -> { Time.now })
          @consumer_key = consumer_key
          @consumer_secret = consumer_secret
          @base_url = base_url
          @clock = clock
        end

        def call
          return @token if @token && @expires_at && @clock.call < @expires_at

          fetch_token
        end

        private

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def fetch_token
          response = Faraday.post("#{@base_url}#{TOKEN_PATH}") do |request|
            request.headers["Accept"] = "application/json"
            request.headers["Content-Type"] = "application/json"
            request.body = JSON.generate(consumer_key: @consumer_key, consumer_secret: @consumer_secret)
          end
          body = JSON.parse(response.body)
          token = body["token"]
          raise_auth_error(response, body) unless response.success? && token

          @token = token
          @expires_at = @clock.call + 270
          @token
        rescue Faraday::Error, JSON::ParserError => e
          raise Lipwa::GatewayError.new("Pesapal authentication failed: #{e.message}", raw: e)
        end

        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
        def raise_auth_error(response, body)
          error = body["error"].is_a?(Hash) ? body["error"] : {}
          message = error["message"] || body["message"] || "Pesapal authentication failed"
          raise Lipwa::GatewayError.new(message, code: (error["code"] || response.status).to_s, raw: body)
        end
      end
    end
  end
end
