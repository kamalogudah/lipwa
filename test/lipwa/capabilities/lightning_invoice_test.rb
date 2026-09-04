# frozen_string_literal: true

require "test_helper"

class LightningInvoiceTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::LightningInvoice

  configure do |c|
    c.base_url = "https://lnbits.example.com"
    c.auth_strategy = Lipwa::AuthStrategies::ApiKey.new("invoice-key")
  end
end

module Lipwa
  module Capabilities
    class LightningInvoiceTest < Minitest::Test
      ENDPOINT = "https://lnbits.example.com/api/v1/payments"
      PAYMENT_HASH = "abc123paymenthash"

      def test_create_invoice_posts_lnbits_fields_and_maps_response
        request = stub_request(:post, ENDPOINT)
                  .with(
                    headers: { "X-Api-Key" => "invoice-key" },
                    body: {
                      out: false,
                      amount: 1_500,
                      memo: "Order 123",
                      expiry: 900,
                      webhook: "https://example.com/webhooks/lightning"
                    }.to_json
                  )
                  .to_return(json_response(payment_hash: PAYMENT_HASH, payment_request: "lnbc15..."))

        result = gateway.create_invoice(
          amount_sats: 1_500,
          memo: "Order 123",
          expiry: 900,
          webhook_url: "https://example.com/webhooks/lightning"
        )

        assert_requested request
        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal PAYMENT_HASH, response.provider_reference
        assert_equal "lnbc15...", response.raw["payment_request"]
        assert_nil response.message
      end

      def test_create_invoice_omits_optional_fields
        stub_request(:post, ENDPOINT)
          .with(body: { out: false, amount: 21 }.to_json)
          .to_return(json_response(payment_hash: PAYMENT_HASH, payment_request: "lnbc..."))

        assert gateway.create_invoice(amount_sats: 21).success?
      end

      def test_check_invoice_paid_is_successful
        stub_request(:get, "#{ENDPOINT}/#{PAYMENT_HASH}")
          .to_return(json_response(paid: true))

        result = gateway.check_invoice(payment_hash: PAYMENT_HASH)

        assert result.success?
        assert result.value!.success?
        assert_equal PAYMENT_HASH, result.value!.provider_reference
      end

      def test_check_invoice_unpaid_is_still_a_success_result
        stub_request(:get, "#{ENDPOINT}/#{PAYMENT_HASH}")
          .to_return(json_response(paid: false))

        result = gateway.check_invoice(payment_hash: PAYMENT_HASH)

        assert result.success?
        refute result.value!.success?
        assert_equal false, result.value!.raw["paid"]
      end

      def test_validation_failure_makes_no_http_call
        result = gateway.create_invoice(amount_sats: 0)

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, ENDPOINT
      end

      def test_transport_error_returns_failure
        stub_request(:get, "#{ENDPOINT}/#{PAYMENT_HASH}")
          .to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = gateway.check_invoice(payment_hash: PAYMENT_HASH)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      private

      def gateway
        LightningInvoiceTestGateway.new
      end

      def json_response(body)
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: body.to_json
        }
      end
    end
  end
end
