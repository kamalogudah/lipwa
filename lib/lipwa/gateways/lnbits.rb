# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/lightning_invoice"
require_relative "../capabilities/lightning_payment"

module Lipwa
  module Gateways
    # LNbits gateway. Each wallet supplies an instance URL and a scoped
    # invoice/read key capable of creating and checking invoices.
    class Lnbits < Lipwa::Gateway
      include Lipwa::Capabilities::LightningInvoice
      include Lipwa::Capabilities::LightningPayment

      setting :invoice_key
      setting :admin_key

      private

      def lightning_payment_http
        @lightning_payment_http ||= build_admin_http_adapter
      end

      def build_admin_http_adapter
        config = self.class.config
        ensure_lnbits_admin_config_present!(config)

        HttpAdapter.new(**http_adapter_options(config, config.admin_key))
      end

      def build_http_adapter
        config = self.class.config
        ensure_lnbits_config_present!(config)

        HttpAdapter.new(**http_adapter_options(config, config.invoice_key))
      end

      def http_adapter_options(config, api_key)
        {
          base_url: config.base_url,
          auth_strategy: AuthStrategies::ApiKey.new(api_key),
          timeout: config.timeout || Lipwa.config.default_timeout,
          open_timeout: config.open_timeout,
          logger: config.logger || Lipwa.config.logger,
          adapter: Lipwa.config.adapter
        }
      end

      def ensure_lnbits_config_present!(config)
        return if config.base_url && config.invoice_key

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing base_url/invoice_key — set them via .configure"
      end

      def ensure_lnbits_admin_config_present!(config)
        return if config.base_url && config.admin_key

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing base_url/admin_key — set them via .configure"
      end
    end
  end
end

Lipwa::Gateways.register(:lnbits, Lipwa::Gateways::Lnbits)
