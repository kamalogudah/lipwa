# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Webhooks
    class MpesaTest < Minitest::Test
      STK_CALLBACK_SUCCESS = {
        "Body" => {
          "stkCallback" => {
            "MerchantRequestID" => "29115-34620561-1",
            "CheckoutRequestID" => "ws_CO_191220191020363925",
            "ResultCode" => 0,
            "ResultDesc" => "The service request is processed successfully.",
            "CallbackMetadata" => {
              "Item" => [
                { "Name" => "Amount", "Value" => 1 },
                { "Name" => "MpesaReceiptNumber", "Value" => "NLJ7RT61SV" }
              ]
            }
          }
        }
      }.freeze

      STK_CALLBACK_FAILURE = {
        "Body" => {
          "stkCallback" => {
            "MerchantRequestID" => "29115-34620561-1",
            "CheckoutRequestID" => "ws_CO_191220191020363925",
            "ResultCode" => 1032,
            "ResultDesc" => "Request cancelled by user."
          }
        }
      }.freeze

      C2B_CONFIRMATION = {
        "TransactionType" => "Pay Bill",
        "TransID" => "RKTQDM7108",
        "TransAmount" => "10",
        "BusinessShortCode" => "600584",
        "BillRefNumber" => "ORDER-123",
        "MSISDN" => "254712345678"
      }.freeze

      def test_parses_stk_callback_as_success
        result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: STK_CALLBACK_SUCCESS)

        event = result.value!
        assert event.success?
        assert_equal :stk_callback, event.event_type
        assert_equal "ws_CO_191220191020363925", event.provider_reference
        assert_equal "The service request is processed successfully.", event.message
      end

      def test_parses_stk_callback_as_failure_on_non_zero_result_code
        result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: STK_CALLBACK_FAILURE)

        event = result.value!
        refute event.success?
        assert_equal "Request cancelled by user.", event.message
      end

      def test_parses_c2b_payload_as_a_c2b_event
        result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: C2B_CONFIRMATION)

        event = result.value!
        assert event.success?
        assert_equal :c2b, event.event_type
        assert_equal "RKTQDM7108", event.provider_reference
      end

      def test_accepts_a_raw_json_string_body
        result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: JSON.generate(C2B_CONFIRMATION))

        assert_equal "RKTQDM7108", result.value!.provider_reference
      end

      def test_invalid_json_string_body_returns_failure
        result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: "{not valid json")

        assert result.failure?
        assert_instance_of Lipwa::WebhookParseError, result.failure
      end

      def test_verify_signature_true_for_a_trusted_source_ip
        event = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: C2B_CONFIRMATION).value!

        assert event.verify_signature(source_ip: "196.201.214.200")
      end

      def test_verify_signature_false_for_an_untrusted_source_ip
        event = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: C2B_CONFIRMATION).value!

        refute event.verify_signature(source_ip: "1.2.3.4")
      end

      def test_verify_signature_false_without_a_source_ip
        event = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: C2B_CONFIRMATION).value!

        refute event.verify_signature
      end
    end
  end
end
