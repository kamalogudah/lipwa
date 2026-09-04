# frozen_string_literal: true

require "test_helper"

class LnbitsIntegrationTestGateway < Lipwa::Gateways::Lnbits
  configure do |c|
    c.base_url = "https://lnbits.test"
    c.invoice_key = "test-lnbits-invoice-key"
    c.admin_key = "test-lnbits-admin-key"
  end
end

module Lipwa
  module Gateways
    # Drives the assembled LNbits gateway (API-key auth + LightningInvoice
    # capability) through sanitized VCR cassettes representative of a
    # self-hosted LNbits instance.
    class LnbitsIntegrationTest < Minitest::Test
      PAYMENT_HASH = "abc123paymenthash"

      def test_create_invoice_success
        VCR.use_cassette("lnbits/create_invoice_success") do
          result = gateway.create_invoice(
            amount_sats: 1_500,
            memo: "Order 123",
            expiry: 900,
            webhook_url: "https://example.com/webhooks/lnbits?token=test-token"
          )

          assert result.success?
          response = result.value!
          assert response.success?
          assert_equal PAYMENT_HASH, response.provider_reference
          assert_equal "lnbc15u1example", response.raw["payment_request"]
        end
      end

      def test_check_invoice_paid
        VCR.use_cassette("lnbits/check_invoice_paid") do
          result = gateway.check_invoice(payment_hash: PAYMENT_HASH)

          assert result.success?
          response = result.value!
          assert response.success?
          assert_equal PAYMENT_HASH, response.provider_reference
          assert_equal true, response.raw["paid"]
        end
      end

      def test_check_invoice_unpaid
        VCR.use_cassette("lnbits/check_invoice_unpaid") do
          result = gateway.check_invoice(payment_hash: PAYMENT_HASH)

          assert result.success?
          response = result.value!
          refute response.success?
          assert_equal PAYMENT_HASH, response.provider_reference
          assert_equal false, response.raw["paid"]
        end
      end

      def test_pay_invoice_success
        VCR.use_cassette("lnbits/pay_invoice_success") do
          result = gateway.pay_invoice(bolt11: "lnbc15u1outbound")

          assert result.success?
          response = result.value!
          assert response.success?
          assert_equal "outbound123paymenthash", response.provider_reference
          assert_equal "success", response.raw["status"]
        end
      end

      def test_check_outbound_payment_pending
        VCR.use_cassette("lnbits/check_payment_pending") do
          result = gateway.check_payment(payment_hash: "outbound123paymenthash")

          assert result.success?
          response = result.value!
          refute response.success?
          assert_equal "pending", response.raw["status"]
        end
      end

      private

      def gateway
        LnbitsIntegrationTestGateway.new
      end
    end
  end
end
