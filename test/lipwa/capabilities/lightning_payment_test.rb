# frozen_string_literal: true

require "test_helper"

class LightningPaymentTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::LightningPayment

  configure do |c|
    c.base_url = "https://lnbits.example.com"
    c.auth_strategy = Lipwa::AuthStrategies::ApiKey.new("admin-key")
  end
end

module Lipwa
  module Capabilities
    class LightningPaymentTest < Minitest::Test
      ENDPOINT = "https://lnbits.example.com/api/v1/payments"
      PAYMENT_HASH = "outbound123paymenthash"

      def test_pay_invoice_posts_outbound_fields_and_maps_success
        request = stub_request(:post, ENDPOINT)
                  .with(
                    headers: { "X-Api-Key" => "admin-key" },
                    body: { out: true, bolt11: "lnbc15u1example" }.to_json
                  )
                  .to_return(json_response(payment_hash: PAYMENT_HASH, status: "success"))

        result = gateway.pay_invoice(bolt11: "lnbc15u1example")

        assert_requested request
        assert result.success?
        assert result.value!.success?
        assert_equal PAYMENT_HASH, result.value!.provider_reference
      end

      def test_pay_invoice_preserves_pending_state_without_claiming_success
        stub_request(:post, ENDPOINT)
          .to_return(json_response(payment_hash: PAYMENT_HASH, status: "pending"))

        response = gateway.pay_invoice(bolt11: "lnbc15u1example").value!

        refute response.success?
        assert_equal "pending", response.raw["status"]
      end

      def test_check_payment_maps_paid_response
        stub_request(:get, "#{ENDPOINT}/#{PAYMENT_HASH}")
          .to_return(json_response(paid: true, status: "success"))

        response = gateway.check_payment(payment_hash: PAYMENT_HASH).value!

        assert response.success?
        assert_equal PAYMENT_HASH, response.provider_reference
      end

      def test_check_payment_preserves_failed_state
        stub_request(:get, "#{ENDPOINT}/#{PAYMENT_HASH}")
          .to_return(json_response(paid: false, status: "failed"))

        response = gateway.check_payment(payment_hash: PAYMENT_HASH).value!

        refute response.success?
        assert_equal "failed", response.raw["status"]
      end

      def test_validation_failure_makes_no_http_call
        result = gateway.pay_invoice(bolt11: "")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, ENDPOINT
      end

      def test_transport_error_is_an_unknown_outcome_failure
        stub_request(:post, ENDPOINT)
          .to_raise(Faraday::TimeoutError.new("payment result timed out"))

        result = gateway.pay_invoice(bolt11: "lnbc15u1example")

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      private

      def gateway
        LightningPaymentTestGateway.new
      end

      def json_response(body)
        { status: 200, headers: { "Content-Type" => "application/json" }, body: body.to_json }
      end
    end
  end
end
