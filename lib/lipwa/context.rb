# frozen_string_literal: true

require "delegate"
require_relative "gateways"

module Lipwa
  # An explicit, immutable configuration scope with its own gateway instances.
  class Context
    # Delegates settings to Dry::Configurable so constructors and errors survive.
    class Builder < SimpleDelegator
      def initialize(config, gateway_configs)
        super(config)
        @gateway_configs = gateway_configs
      end

      def gateway(name)
        config = @gateway_configs[name]
        yield config if block_given?
        config
      end
    end
    private_constant :Builder

    attr_reader :config

    def initialize
      @config = snapshot(Lipwa.config)
      classes = Gateways.gateway_classes
      gateway_configs = snapshot_gateways(classes)
      yield Builder.new(config, gateway_configs) if block_given?
      finalize(config)
      @gateways = build_gateways(classes, gateway_configs)
      freeze
    end

    def gateway(name)
      @gateways[name]
    end

    private

    def snapshot_gateways(classes)
      Dry::Container.new.tap do |configs|
        classes.each { |name, klass| configs.register(name, snapshot(klass.config)) }
      end
    end

    def build_gateways(classes, gateway_configs)
      Dry::Container.new.tap do |gateways|
        classes.each do |name, klass|
          provider_config = finalize(gateway_configs[name])
          gateways.register(name, memoize: true) { klass.new(config: provider_config, global_config: config) }
        end
      end
    end

    def finalize(config)
      config.values.transform_values! { |value| freeze_value(copy_value(value)) }
      config.finalize!
      config.values.freeze
      config
    end

    def freeze_value(value)
      case value
      when Dry::Configurable::Config then finalize(value)
      when Array then value.each { |item| freeze_value(item) }.freeze
      when Hash then value.each_value { |item| freeze_value(item) }.freeze
      when String then value.freeze
      end
      value
    end

    def snapshot(source)
      source.dup.tap do |copy|
        copy.values.transform_values! { |value| copy_value(value) }
      end
    end

    # Copy configuration data without duplicating services such as loggers or
    # callable clocks, and without running setting constructors a second time.
    def copy_value(value)
      case value
      when Dry::Configurable::Config then snapshot(value)
      when String then value.dup
      when Array then value.map { |item| copy_value(item) }
      when Hash then value.transform_values { |item| copy_value(item) }
      else value
      end
    end
  end
end
