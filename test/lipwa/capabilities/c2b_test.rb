# frozen_string_literal: true

require "test_helper"

class C2bTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::C2B

  setting :shortcode

  configure do |c|
    c.base_url = "https://c2b.example.com"
    c.shortcode = "600584"
  end
end

module Lipwa
  module Capabilities
    class C2bTest < Minitest::Test
      include Dry::Monads[:result]

      REGISTER_URLS_ENDPOINT = "https://c2b.example.com/mpesa/c2b/v1/registerurl"
      SIMULATE_ENDPOINT = "https://c2b.example.com/mpesa/c2b/v1/simulate"

      def test_register_urls_invalid_params_return_failure_without_an_http_call
        gateway = C2bTestGateway.new

        result = gateway.register_urls(**valid_register_urls_args, validation_url: "http://example.com/validate")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, REGISTER_URLS_ENDPOINT
      end

      def test_register_urls_successful_response_returns_success_with_provider_reference
        stub_request(:post, REGISTER_URLS_ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "success",
              OriginatorConversationID: "12362-3240472-1"
            }.to_json
          )

        result = C2bTestGateway.new.register_urls(**valid_register_urls_args)

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "12362-3240472-1", response.provider_reference
      end

      def test_register_urls_request_body_includes_daraja_fields
        stub_request(:post, REGISTER_URLS_ENDPOINT)
          .with { |req| register_urls_body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", ResponseDescription: "success" }.to_json
          )

        result = C2bTestGateway.new.register_urls(**valid_register_urls_args)

        assert result.success?
      end

      def test_register_urls_gateway_error_returns_failure
        stub_request(:post, REGISTER_URLS_ENDPOINT).to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = C2bTestGateway.new.register_urls(**valid_register_urls_args)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      def test_simulate_invalid_params_return_failure_without_an_http_call
        gateway = C2bTestGateway.new

        result = gateway.simulate(**valid_simulate_args, phone_number: "not-a-phone-number")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, SIMULATE_ENDPOINT
      end

      def test_simulate_successful_response_returns_success_with_provider_reference
        stub_request(:post, SIMULATE_ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "Accept the service request successfully.",
              ConversationID: "AG_20180402_00004a92452ef78e864d"
            }.to_json
          )

        result = C2bTestGateway.new.simulate(**valid_simulate_args)

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "AG_20180402_00004a92452ef78e864d", response.provider_reference
      end

      def test_simulate_request_body_includes_daraja_fields
        stub_request(:post, SIMULATE_ENDPOINT)
          .with { |req| simulate_body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", ConversationID: "AG_123" }.to_json
          )

        result = C2bTestGateway.new.simulate(**valid_simulate_args)

        assert result.success?
      end

      def test_simulate_gateway_error_returns_failure
        stub_request(:post, SIMULATE_ENDPOINT).to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = C2bTestGateway.new.simulate(**valid_simulate_args)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      private

      def register_urls_body_matches?(req)
        payload = JSON.parse(req.body)
        payload["ShortCode"] == "600584" &&
          payload["ResponseType"] == "Completed" &&
          payload["ConfirmationURL"] == "https://example.com/webhooks/mpesa/confirm" &&
          payload["ValidationURL"] == "https://example.com/webhooks/mpesa/validate"
      end

      def simulate_body_matches?(req)
        payload = JSON.parse(req.body)
        payload["ShortCode"] == "600584" &&
          payload["CommandID"] == "CustomerPayBillOnline" &&
          payload["Amount"] == 100 &&
          payload["Msisdn"] == "254712345678" &&
          payload["BillRefNumber"] == "ORDER-123"
      end

      def valid_register_urls_args
        {
          validation_url: "https://example.com/webhooks/mpesa/validate",
          confirmation_url: "https://example.com/webhooks/mpesa/confirm"
        }
      end

      def valid_simulate_args
        {
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          phone_number: "254712345678",
          bill_ref_number: "ORDER-123"
        }
      end
    end
  end
end
