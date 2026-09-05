# frozen_string_literal: true

require "dry/configurable"
require_relative "errors"
require_relative "types"
require_relative "capability"
require_relative "auth_strategies"
require_relative "http_adapter"
require_relative "configuration_snapshot"

module Lipwa
  # Abstract base every provider gateway (Mpesa, CoopBank, Jenga, ...)
  # inherits from. Holds the gateway's Dry::Configurable settings, lazily
  # builds the shared HttpAdapter from them, and answers `capability?`
  # by checking which Lipwa::Capabilities::* modules the subclass
  # actually included — see Lipwa::Capability.
  class Gateway
    extend Dry::Configurable

    setting :env, default: :sandbox, constructor: Types::Environment
    setting :base_url
    setting :timeout
    setting :open_timeout, default: 5
    setting :logger
    setting :auth_strategy

    class << self
      def capabilities
        @capabilities ||= Set.new
      end

      # Called by Lipwa::Capability#included — not meant to be called
      # directly.
      def register_capability(name)
        capabilities << name.to_sym
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@capabilities, capabilities.dup)
      end
    end

    attr_reader :config, :global_config

    # Explicit snapshots win over defaults captured at construction time.
    def initialize(config: nil, global_config: nil)
      @config = ConfigurationSnapshot.snapshot(config || self.class.config)
      strategy = @config.auth_strategy
      @config.auth_strategy = strategy.respond_to?(:apply) ? strategy.dup : strategy&.call
      ConfigurationSnapshot.finalize(@config)
      @global_config = ConfigurationSnapshot.finalize(
        ConfigurationSnapshot.snapshot(global_config || Lipwa.config)
      )
    end

    def capability?(name)
      self.class.capabilities.include?(name.to_sym)
    end

    def http
      @http ||= build_http_adapter
    end

    private

    def build_http_adapter
      config = self.config
      ensure_base_url_configured!(config)

      HttpAdapter.new(
        base_url: config.base_url,
        auth_strategy: config.auth_strategy || AuthStrategies::None.new,
        timeout: config.timeout || global_config.default_timeout,
        open_timeout: config.open_timeout,
        logger: config.logger || global_config.logger,
        adapter: global_config.adapter
      )
    end

    def ensure_base_url_configured!(config)
      return if config.base_url

      raise Lipwa::ConfigurationError, "#{self.class} is missing `base_url` — set it via .configure"
    end
  end
end
