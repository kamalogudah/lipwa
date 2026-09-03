# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Webhooks
    class CoopBankTest < Minitest::Test
      SUCCESS_CALLBACK = {
        "MessageReference" => "8f618d57-14e2-4e56-91f8-649ca920318b",
        "MessageCode" => 0,
        "MessageDescription" => "SUCCESS",
        "Source" => { "ResponseCode" => "00" },
        "Destinations" => [{ "ResponseCode" => "00" }]
      }.freeze

      def test_parses_coop_callback
        result = Lipwa::Webhook.parse_webhook(provider: :coop_bank, body: SUCCESS_CALLBACK.to_json)

        assert result.success?
        event = result.value!
        assert_equal :coop_bank, event.provider
        assert_equal :transaction_status, event.event_type
        assert event.success?
        assert_equal SUCCESS_CALLBACK["MessageReference"], event.provider_reference
        assert_equal "SUCCESS", event.message
        assert_equal SUCCESS_CALLBACK, event.raw
      end

      def test_nonzero_message_code_is_unsuccessful
        payload = SUCCESS_CALLBACK.merge("MessageCode" => -13,
                                         "MessageDescription" => "MESSAGE REFERENCE DOES NOT EXIST")

        event = Lipwa::Webhook.parse_webhook(provider: :coop_bank, body: payload).value!

        refute event.success?
        assert_equal "MESSAGE REFERENCE DOES NOT EXIST", event.message
      end
    end
  end
end
