# frozen_string_literal: true

require "test_helper"

class StkPushTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::StkPush

  setting :shortcode
  setting :passkey

  configure do |c|
    c.base_url = "https://stk.example.com"
    c.shortcode = "174379"
    c.passkey = "test-passkey"
  end
end

module Lipwa
  module Capabilities
    class StkPushTest < Minitest::Test
      include Dry::Monads[:result]

      ENDPOINT = "https://stk.example.com/mpesa/stkpush/v1/processrequest"

      def test_invalid_params_return_failure_without_an_http_call
        gateway = StkPushTestGateway.new

        result = gateway.stk_push(**valid_args, phone_number: "not-a-phone-number")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, ENDPOINT
      end

      def test_successful_response_returns_success_with_provider_reference
        stub_request(:post, ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "Success. Request accepted for processing",
              CheckoutRequestID: "ws_CO_123456789"
            }.to_json
          )

        result = StkPushTestGateway.new.stk_push(**valid_args)

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "ws_CO_123456789", response.provider_reference
      end

      def test_forwards_idempotency_key_to_gateway_request
        stub_request(:post, ENDPOINT)
          .with(headers: { "Idempotency-Key" => "order-123-attempt" })
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", CheckoutRequestID: "ws_CO_123456789" }.to_json
          )

        result = StkPushTestGateway.new.stk_push(**valid_args, idempotency_key: "order-123-attempt")

        assert result.success?
      end

      def test_gateway_error_returns_failure
        stub_request(:post, ENDPOINT).to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = StkPushTestGateway.new.stk_push(**valid_args)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      def test_request_body_includes_daraja_fields
        stub_request(:post, ENDPOINT)
          .with { |req| body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", CheckoutRequestID: "ws_CO_123456789" }.to_json
          )

        result = StkPushTestGateway.new.stk_push(**valid_args)

        assert result.success?
      end

      private

      def body_matches?(req)
        payload = JSON.parse(req.body)
        payload["BusinessShortCode"] == "174379" &&
          payload["PhoneNumber"] == "254712345678" &&
          payload["Amount"] == 100 &&
          payload["AccountReference"] == "ORDER-123" &&
          payload["CallBackURL"] == "https://example.com/webhooks/mpesa"
      end

      def valid_args
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          account_reference: "ORDER-123",
          callback_url: "https://example.com/webhooks/mpesa"
        }
      end
    end
  end
end
