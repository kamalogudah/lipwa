# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class LnbitsTest < Minitest::Test
      def teardown
        Lnbits.config.base_url = nil
        Lnbits.config.invoice_key = nil
        Lnbits.config.admin_key = nil
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

      def test_capability_lightning_payment_is_registered
        assert Lnbits.new.capability?(:lightning_payment)
      end

      def test_outbound_payment_requires_admin_key_without_upgrading_invoice_key
        configure_lnbits

        error = assert_raises(Lipwa::ConfigurationError) do
          Lnbits.new.pay_invoice(bolt11: "lnbc15u1example")
        end

        assert_match(/admin_key/, error.message)
      end

      def test_receive_operations_do_not_fall_back_to_admin_key
        Lnbits.configure do |config|
          config.base_url = "https://lnbits.example.com"
          config.admin_key = "admin-key"
        end

        error = assert_raises(Lipwa::ConfigurationError) { Lnbits.new.http }

        assert_match(/invoice_key/, error.message)
      end

      def test_outbound_payment_uses_admin_key_not_invoice_key
        configure_lnbits(admin_key: "admin-key")
        request = stub_request(:post, "https://lnbits.example.com/api/v1/payments")
                  .with(headers: { "X-Api-Key" => "admin-key" })
                  .to_return(
                    status: 201,
                    headers: { "Content-Type" => "application/json" },
                    body: { payment_hash: "outbound-hash", status: "success" }.to_json
                  )

        result = Lnbits.new.pay_invoice(bolt11: "lnbc15u1example")

        assert result.success?
        assert_requested request
      end

      def test_receive_operation_uses_invoice_key_not_admin_key
        configure_lnbits(admin_key: "admin-key")
        request = stub_request(:get, "https://lnbits.example.com/api/v1/payments/incoming-hash")
                  .with(headers: { "X-Api-Key" => "invoice-key" })
                  .to_return(
                    status: 200,
                    headers: { "Content-Type" => "application/json" },
                    body: { paid: true }.to_json
                  )

        result = Lnbits.new.check_invoice(payment_hash: "incoming-hash")

        assert result.success?
        assert_requested request
      end

      def test_registered_in_gateways_container
        assert_same Lnbits, Lipwa::Gateways[:lnbits].class
      end

      private

      def configure_lnbits(admin_key: nil)
        Lnbits.configure do |config|
          config.base_url = "https://lnbits.example.com"
          config.invoice_key = "invoice-key"
          config.admin_key = admin_key
        end
      end
    end
  end
end
