# frozen_string_literal: true

require_relative "configuration"
require_relative "logging"

module Lipwa
  # Copies setting data while preserving service objects such as loggers.
  module ConfigurationSnapshot
    module_function

    def finalize(config)
      config.values.transform_values! { |value| freeze_value(copy_value(value)) }
      config.define_singleton_method(:inspect) do
        values = Lipwa::Logging::Redactor.call(to_h)
        "#<#{self.class} values=#{values.inspect}>"
      end
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
