# frozen_string_literal: true

require_relative "../gateway"
require_relative "../gateways"
require_relative "../capabilities/lightning_invoice"

module Lipwa
  module Gateways
    # LNbits gateway. Each wallet supplies an instance URL and a scoped
    # invoice/read key capable of creating and checking invoices.
    class Lnbits < Lipwa::Gateway
      include Lipwa::Capabilities::LightningInvoice

      setting :invoice_key

      private

      def build_http_adapter
        config = self.class.config
        ensure_lnbits_config_present!(config)

        HttpAdapter.new(**http_adapter_options(config))
      end

      def http_adapter_options(config)
        {
          base_url: config.base_url,
          auth_strategy: AuthStrategies::ApiKey.new(config.invoice_key),
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
    end
  end
end

Lipwa::Gateways.register(:lnbits, Lipwa::Gateways::Lnbits)
