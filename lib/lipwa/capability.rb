# frozen_string_literal: true

require_relative "errors"

module Lipwa
  # Mixin for capability modules (Lipwa::Capabilities::StkPush,
  # Lipwa::Capabilities::Disbursement, ...). A capability module extends
  # this and declares its `capability_name`; when the module is included
  # into a Gateway subclass, that name is auto-registered so
  # `gateway.capability?(:stk_push)` reflects reality — the method
  # existing — instead of a hand-maintained list that can drift.
  #
  #   module Lipwa
  #     module Capabilities
  #       module StkPush
  #         extend Lipwa::Capability
  #         self.capability_name = :stk_push
  #
  #         def stk_push(...); end
  #       end
  #     end
  #   end
  module Capability
    def self.extended(capability_module)
      capability_module.singleton_class.attr_accessor :capability_name
    end

    def included(base)
      super
      unless capability_name
        raise Lipwa::ConfigurationError, "#{self} must set `self.capability_name` before being included"
      end

      base.register_capability(capability_name)
    end
  end
end
