# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/c2b"
require_relative "../capabilities/stk_push"
require_relative "../capabilities/disbursement"
require_relative "../capabilities/status_query"
require_relative "../capabilities/refund"

module Lipwa
  module Gateways
    # Safaricom Daraja gateway. base_url and auth_strategy are derived
    # automatically from env/consumer_key/consumer_secret rather than set
    # directly, since Daraja's OAuth + sandbox/production hosts are fixed
    # per environment.
    class Mpesa < Lipwa::Gateway
      include Lipwa::Capabilities::C2B
      include Lipwa::Capabilities::StkPush
      include Lipwa::Capabilities::Disbursement
      include Lipwa::Capabilities::StatusQuery
      include Lipwa::Capabilities::Refund

      setting :consumer_key
      setting :consumer_secret
      setting :shortcode
      setting :passkey
      setting :initiator_name
      setting :initiator_password
      setting :security_credential_cert

      private

      def build_http_adapter
        config = self.config
        ensure_mpesa_config_present!(config)

        HttpAdapter.new(**http_adapter_options(config))
      end

      def http_adapter_options(config)
        {
          base_url: Auth::BASE_URLS.fetch(config.env),
          auth_strategy: AuthStrategies::BearerToken.new(build_auth(config)),
          timeout: config.timeout || global_config.default_timeout,
          open_timeout: config.open_timeout,
          logger: config.logger || global_config.logger,
          adapter: global_config.adapter
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
require_relative "mpesa/security_credential"

Lipwa::Gateways.register(:mpesa, Lipwa::Gateways::Mpesa)
