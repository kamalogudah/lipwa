# frozen_string_literal: true

module Lipwa
  module AuthStrategies
    # Interface every auth strategy implements. An HttpAdapter is handed
    # one of these and calls #apply on every outgoing request, letting
    # the strategy mutate headers (bearer token, HMAC/RSA signature,
    # timestamp, whatever the provider needs) without HttpAdapter knowing
    # which kind of auth it's dealing with.
    class Base
      def inspect
        "#<#{self.class}:0x#{object_id.to_s(16)}>"
      end

      # env is a Faraday::Env — mutate env.request_headers / env.body
      # in place. Must be implemented by subclasses.
      def apply(env)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end
    end
  end
end
