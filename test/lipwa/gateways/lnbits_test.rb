# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class LnbitsTest < Minitest::Test
      def teardown
        Lnbits.config.base_url = nil
        Lnbits.config.invoice_key = nil
      end

      def test_missing_config_raises_configuration_error_at_call_time
        assert_raises(Lipwa::ConfigurationError) { Lnbits.new.http }
      end

      def test_missing_base_url_raises_configuration_error
        Lnbits.config.invoice_key = "invoice-key"

        assert_raises(Lipwa::ConfigurationError) { Lnbits.new.http }
      end

      def test_missing_invoice_key_raises_configuration_error
        Lnbits.config.base_url = "https://lnbits.example.com"

        assert_raises(Lipwa::ConfigurationError) { Lnbits.new.http }
      end

      def test_builds_adapter_with_instance_url_and_invoice_key
        configure_lnbits

        gateway = Lnbits.new

        assert_equal "https://lnbits.example.com", gateway.http.base_url
        assert_instance_of Lipwa::AuthStrategies::ApiKey, gateway.http.auth_strategy
      end

      def test_capability_lightning_invoice_is_registered
        assert Lnbits.new.capability?(:lightning_invoice)
      end

      def test_registered_in_gateways_container
        assert_same Lnbits, Lipwa::Gateways[:lnbits].class
      end

      private

      def configure_lnbits
        Lnbits.configure do |config|
          config.base_url = "https://lnbits.example.com"
          config.invoice_key = "invoice-key"
        end
      end
    end
  end
end
