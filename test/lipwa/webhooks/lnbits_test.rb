# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Webhooks
    class LnbitsTest < Minitest::Test
      PAID_PAYMENT = {
        "payment_hash" => "abc123", "amount" => 2_100,
        "memo" => "Order ORDER-123", "bolt11" => "lnbc21u1example", "paid" => true
      }.freeze

      def test_parses_a_paid_payment
        event = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: PAID_PAYMENT).value!
        assert event.success?
        assert_equal :payment, event.event_type
        assert_equal "abc123", event.provider_reference
        assert_equal "Order ORDER-123", event.message
        assert_equal PAID_PAYMENT, event.raw
      end

      def test_parses_an_explicitly_unpaid_payment
        event = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: PAID_PAYMENT.merge("paid" => false)).value!
        refute event.success?
      end

      def test_treats_missing_paid_field_as_a_payment_notification
        event = Lipwa::Webhook.parse_webhook(
          provider: :lnbits, body: PAID_PAYMENT.reject { |key, _| key == "paid" }
        ).value!
        assert event.success?
      end

      def test_verify_signature_accepts_a_matching_token
        event = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: PAID_PAYMENT).value!
        assert event.verify_signature(expected_token: "invoice-secret", provided_token: "invoice-secret")
      end

      def test_verify_signature_rejects_a_mismatching_token
        event = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: PAID_PAYMENT).value!
        refute event.verify_signature(expected_token: "invoice-secret", provided_token: "different-token")
      end

      def test_verify_signature_rejects_a_missing_token
        event = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: PAID_PAYMENT).value!
        refute event.verify_signature(expected_token: "invoice-secret")
        refute event.verify_signature(provided_token: "invoice-secret")
      end

      def test_invalid_json_body_returns_failure
        result = Lipwa::Webhook.parse_webhook(provider: :lnbits, body: "{not valid json")
        assert result.failure?
        assert_instance_of Lipwa::WebhookParseError, result.failure
      end
    end
  end
end
