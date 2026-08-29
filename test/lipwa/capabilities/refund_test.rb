# frozen_string_literal: true

require "test_helper"

class RefundTestGateway < Lipwa::Gateway
  include Lipwa::Capabilities::Refund

  setting :shortcode
  setting :initiator_name
  setting :initiator_password
  setting :security_credential_cert

  configure do |c|
    c.base_url = "https://refund.example.com"
    c.shortcode = "600584"
    c.initiator_name = "testapi"
    c.initiator_password = "test-initiator-password"
    c.security_credential_cert = TEST_MPESA_CERT
  end
end

class RefundMissingCredentialsGateway < Lipwa::Gateway
  include Lipwa::Capabilities::Refund

  setting :shortcode
  setting :initiator_name
  setting :initiator_password
  setting :security_credential_cert

  configure do |c|
    c.base_url = "https://refund.example.com"
    c.shortcode = "600584"
  end
end

module Lipwa
  module Capabilities
    class RefundTest < Minitest::Test
      include Dry::Monads[:result]

      ENDPOINT = "https://refund.example.com/mpesa/reversal/v1/request"

      def test_refund_invalid_params_return_failure_without_an_http_call
        gateway = RefundTestGateway.new

        result = gateway.refund(**valid_args, transaction_id: "")

        assert result.failure?
        assert_instance_of Lipwa::ValidationError, result.failure
        assert_not_requested :post, ENDPOINT
      end

      def test_refund_successful_response_returns_success_with_provider_reference
        stub_request(:post, ENDPOINT)
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              ResponseCode: "0",
              ResponseDescription: "Accept the service request successfully.",
              ConversationID: "AG_20180402_00004a92452ef78e864d"
            }.to_json
          )

        result = RefundTestGateway.new.refund(**valid_args)

        assert result.success?
        response = result.value!
        assert response.success?
        assert_equal "AG_20180402_00004a92452ef78e864d", response.provider_reference
      end

      def test_refund_request_body_includes_daraja_fields
        stub_request(:post, ENDPOINT)
          .with { |req| refund_body_matches?(req) }
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { ResponseCode: "0", ConversationID: "AG_123" }.to_json
          )

        result = RefundTestGateway.new.refund(**valid_args)

        assert result.success?
      end

      def test_refund_gateway_error_returns_failure
        stub_request(:post, ENDPOINT).to_raise(Faraday::ConnectionFailed.new("connection reset"))

        result = RefundTestGateway.new.refund(**valid_args)

        assert result.failure?
        assert_instance_of Lipwa::GatewayError, result.failure
      end

      def test_refund_raises_configuration_error_when_initiator_credentials_are_missing
        assert_raises(Lipwa::ConfigurationError) do
          RefundMissingCredentialsGateway.new.refund(**valid_args)
        end
        assert_not_requested :post, ENDPOINT
      end

      private

      def refund_body_matches?(req)
        payload = JSON.parse(req.body)
        payload["Initiator"] == "testapi" &&
          payload["CommandID"] == "TransactionReversal" &&
          payload["TransactionID"] == "OEI2AK4Q16" &&
          payload["Amount"] == 100 &&
          payload["ReceiverParty"] == "600584" &&
          payload["RecieverIdentifierType"] == "11" &&
          !payload["SecurityCredential"].to_s.empty?
      end

      def valid_args
        {
          transaction_id: "OEI2AK4Q16",
          amount: Lipwa::Money.new(amount: 100, currency: "KES"),
          remarks: "Missing item",
          result_url: "https://example.com/webhooks/mpesa/result",
          queue_timeout_url: "https://example.com/webhooks/mpesa/timeout"
        }
      end
    end
  end
end
