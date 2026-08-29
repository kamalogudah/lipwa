# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/c2b"
require_relative "../capabilities/stk_push"

module Lipwa
  module Gateways
    # Safaricom Daraja gateway. base_url and auth_strategy are derived
    # automatically from env/consumer_key/consumer_secret rather than set
    # directly, since Daraja's OAuth + sandbox/production hosts are fixed
    # per environment.
    class Mpesa < Lipwa::Gateway
      include Lipwa::Capabilities::C2B
      include Lipwa::Capabilities::StkPush

      setting :consumer_key
      setting :consumer_secret
      setting :shortcode
      setting :passkey

      private

      def build_http_adapter
        config = self.class.config
        ensure_mpesa_config_present!(config)

        HttpAdapter.new(**http_adapter_options(config))
      end

      def http_adapter_options(config)
        {
          base_url: Auth::BASE_URLS.fetch(config.env),
          auth_strategy: AuthStrategies::BearerToken.new(build_auth(config)),
          timeout: config.timeout || Lipwa.config.default_timeout,
          open_timeout: config.open_timeout,
          logger: config.logger || Lipwa.config.logger,
          adapter: Lipwa.config.adapter
        }
      end

      def build_auth(config)
        Auth.new(consumer_key: config.consumer_key, consumer_secret: config.consumer_secret, env: config.env)
      end

      def ensure_mpesa_config_present!(config)
        return if config.consumer_key && config.consumer_secret && config.shortcode && config.passkey

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing consumer_key/consumer_secret/shortcode/passkey — set them via .configure"
      end
    end
  end
end

require_relative "mpesa/auth"

Lipwa::Gateways.register(:mpesa, Lipwa::Gateways::Mpesa)
