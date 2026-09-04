# frozen_string_literal: true

require_relative "base"

module Lipwa
  module AuthStrategies
    # Sets a static API key header on every request.
    class ApiKey < Base
      def initialize(key, header: "X-Api-Key")
        raise ArgumentError, "key must not be blank" if key.nil? || key.to_s.strip.empty?

        super()
        @key = key
        @header = header
      end

      def apply(env)
        env.request_headers[@header] = @key
      end
    end
  end
end
