# frozen_string_literal: true

require "base64"
require "faraday"
require "json"
require_relative "../../errors"
module Lipwa
  module Gateways
    class CoopBank
      class Auth
        EXPIRY_BUFFER = 60
        def initialize(client_id:, client_secret:, token_url:, clock: -> { Time.now })
          unless client_id && client_secret
            raise Lipwa::ConfigurationError,
                  "CoopBank::Auth requires client_id and client_secret"
          end

          @client_id = client_id
          @client_secret = client_secret
          @token_url = token_url
          @clock = clock
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
            request.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{@client_id}:#{@client_secret}")}"
            request.headers["Content-Type"] = "application/x-www-form-urlencoded"
            request.body = "grant_type=client_credentials"
          end
          body = JSON.parse(response.body)
          unless response.success?
            raise Lipwa::GatewayError.new("Co-op OAuth failed", code: response.status.to_s,
                                                                raw: body)
          end

          @token = body.fetch("access_token")
          @expires_at = @clock.call + body.fetch("expires_in", 3600).to_i - EXPIRY_BUFFER
        rescue Faraday::Error, JSON::ParserError, KeyError => e
          raise Lipwa::GatewayError.new("unexpected Co-op OAuth response: #{e.message}",
                                        raw: defined?(body) ? body : nil)
        end
      end
    end
  end
end
