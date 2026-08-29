# frozen_string_literal: true

require "test_helper"

class DisbursementTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::Disbursement

  setting :shortcode
  setting :initiator_name
  setting :initiator_password
  setting :security_credential_cert

  configure do |c|
    c.base_url = "https://disbursement.example.com"
    c.shortcode = "600584"
    c.initiator_name = "testapi"
    c.initiator_password = "test-initiator-password"
    c.security_credential_cert = TEST_MPESA_CERT
  end
end

class DisbursementMissingCredentialsGateway < Lipwa::Gateway
  include Lipwa::Capabilities::Disbursement

  setting :shortcode
  setting :initiator_name
  setting :initiator_password
  setting :security_credential_cert

  configure do |c|
    c.base_url = "https://disbursement.example.com"
    c.shortcode = "600584"
  end
end

module Lipwa
  module Capabilities
    class DisbursementTest < Minitest::Test
      include Dry::Monads[:result]

      B2C_ENDPOINT = "https://disbursement.example.com/mpesa/b2c/v1/paymentrequest"
      B2B_ENDPOINT = "https://disbursement.example.com/mpesa/b2b/v1/paymentrequest"

      def test_disburse_invalid_params_return_failure_without_an_http_call
        gateway = DisbursementTestGateway.new

        result = gateway.disburse(**valid_b2c_args, party_b: "not-a-phone-number")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, B2C_ENDPOINT
      end

      def test_disburse_b2c_successful_response_returns_success_with_provider_reference
        stub_request(:post, B2C_ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "Accept the service request successfully.",
              ConversationID: "AG_20180402_00004a92452ef78e864d"
            }.to_json
          )

        result = DisbursementTestGateway.new.disburse(**valid_b2c_args)

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "AG_20180402_00004a92452ef78e864d", response.provider_reference
      end

      def test_disburse_b2c_request_body_includes_daraja_fields
        stub_request(:post, B2C_ENDPOINT)
          .with { |req| b2c_body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", ConversationID: "AG_123" }.to_json
          )

        result = DisbursementTestGateway.new.disburse(**valid_b2c_args)

        assert result.success?
      end

      def test_disburse_b2b_successful_response_returns_success_with_provider_reference
        stub_request(:post, B2B_ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "Accept the service request successfully.",
              ConversationID: "AG_20180402_00004a92452ef78e865f"
            }.to_json
          )

        result = DisbursementTestGateway.new.disburse(**valid_b2b_args)

        assert result.success?
        assert_equal "AG_20180402_00004a92452ef78e865f", result.value!.provider_reference
      end

      def test_disburse_b2b_request_body_includes_daraja_fields
        stub_request(:post, B2B_ENDPOINT)
          .with { |req| b2b_body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", ConversationID: "AG_123" }.to_json
          )

        result = DisbursementTestGateway.new.disburse(**valid_b2b_args)

        assert result.success?
      end

      def test_disburse_gateway_error_returns_failure
        stub_request(:post, B2C_ENDPOINT).to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = DisbursementTestGateway.new.disburse(**valid_b2c_args)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      def test_disburse_raises_configuration_error_when_initiator_credentials_are_missing
        assert_raises(Lipwa::ConfigurationError) do
          DisbursementMissingCredentialsGateway.new.disburse(**valid_b2c_args)
        end
        assert_not_requested :post, B2C_ENDPOINT
      end

      private

      def b2c_body_matches?(req)
        payload = JSON.parse(req.body)
        payload["InitiatorName"] == "testapi" &&
          payload["CommandID"] == "SalaryPayment" &&
          payload["Amount"] == 100 &&
          payload["PartyA"] == "600584" &&
          payload["PartyB"] == "254712345678" &&
          payload["Remarks"] == "August salary" &&
          !payload["SecurityCredential"].to_s.empty?
      end

      def b2b_body_matches?(req)
        payload = JSON.parse(req.body)
        payload["Initiator"] == "testapi" &&
          payload["CommandID"] == "BusinessPayBill" &&
          payload["Amount"] == 100 &&
          payload["PartyA"] == "600584" &&
          payload["PartyB"] == "600000" &&
          payload["AccountReference"] == "INV-123" &&
          !payload["SecurityCredential"].to_s.empty?
      end

      def valid_b2c_args
        {
          command_id: "SalaryPayment",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          party_b: "254712345678",
          remarks: "August salary",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout"
        }
      end

      def valid_b2b_args
        {
          command_id: "BusinessPayBill",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          party_b: "600000",
          remarks: "Settlement",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout",
          account_reference: "INV-123"
        }
      end
    end
  end
end
