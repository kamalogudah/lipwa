# frozen_string_literal: true

require_relative "base"

module Lipwa
  module AuthStrategies
    # Sets `Authorization: Bearer <token>` on every request. Covers the
    # OAuth2 client-credentials providers (M-Pesa Daraja, Co-op Bank):
    # each gateway supplies its own token source — typically an object
    # that fetches and caches a token from the provider's OAuth endpoint
    # and refreshes it once expired — as `token_provider`.
    #
    # token_provider must respond to #call and return a token String.
    class BearerToken < Base
      def initialize(token_provider)
        raise ArgumentError, "token_provider must respond to #call" unless token_provider.respond_to?(:call)

        super()
        @token_provider = token_provider
      end

      def apply(env)
        env.request_headers["Authorization"] = "Bearer #{@token_provider.call}"
      end
    end
  end
end
