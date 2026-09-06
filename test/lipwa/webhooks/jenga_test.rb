# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Webhooks
    class JengaTest < Minitest::Test
      IPN = {
        "callbackType" => "IPN",
        "customer" => { "name" => "Jane Doe", "reference" => "ORDER-123" },
        "transaction" => { "reference" => "328411183176", "status" => "SUCCESS", "remarks" => "00:Approved" },
        "bank" => { "transactionType" => "C", "account" => nil }
      }.freeze

      def test_parses_receive_payment_ipn
        event = Lipwa::Webhook.parse_webhook(provider: :jenga, body: IPN).value!

        assert event.success?
        assert_equal :receive_payment, event.event_type
        assert_equal "328411183176", event.provider_reference
        assert_equal "00:Approved", event.message
        assert_equal IPN, event.raw
      end

      def test_non_success_status_is_a_failure
        payload = Marshal.load(Marshal.dump(IPN))
        payload["transaction"]["status"] = "FAILED"

        refute Lipwa::Webhook.parse_webhook(provider: :jenga, body: payload).value!.success?
      end

      def test_accepts_json_and_case_insensitive_authorization_header
        authorization = "Basic #{Base64.strict_encode64("webhook-user:webhook-secret")}"
        event = Lipwa::Webhook.parse_webhook(
          provider: :jenga, body: JSON.generate(IPN), headers: { "authorization" => authorization }
        ).value!

        assert event.verify_signature(username: "webhook-user", password: "webhook-secret")
      end

      def test_rejects_wrong_credentials
        event = parse_with_authorization("Basic #{Base64.strict_encode64("webhook-user:webhook-secret")}")

        refute event.verify_signature(username: "webhook-user", password: "wrong")
      end

      def test_rejects_missing_authorization_header
        event = Lipwa::Webhook.parse_webhook(provider: :jenga, body: IPN).value!

        refute event.verify_signature(username: "webhook-user", password: "webhook-secret")
      end

      private

      def parse_with_authorization(authorization)
        Lipwa::Webhook.parse_webhook(
          provider: :jenga, body: IPN, headers: { "Authorization" => authorization }
        ).value!
      end
    end
  end
end
