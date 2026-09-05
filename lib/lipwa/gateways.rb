# frozen_string_literal: true

require "dry/container"
require_relative "errors"
require_relative "gateway"

module Lipwa
  # Dry::Container-based registry of provider gateways. Providers register
  # their Gateway subclass once (typically at load time); consumers look
  # them up by name instead of hardcoding gateway class names — see
  # Lipwa.gateway.
  module Gateways
    extend Dry::Container::Mixin

    class << self
      def register(key, gateway_class)
        unless gateway_class.is_a?(Class) && gateway_class <= Lipwa::Gateway
          raise Lipwa::ConfigurationError, "#{gateway_class} must be a subclass of Lipwa::Gateway"
        end

        super(key.to_sym, memoize: true) { gateway_class.new }.tap do
          (@gateway_classes ||= {})[key.to_s] = gateway_class
        end
      end

      def gateway_classes
        (@gateway_classes || {}).dup
      end
    end
  end
end
