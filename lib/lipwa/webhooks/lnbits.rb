# frozen_string_literal: true

require "openssl"
require_relative "../webhook"

module Lipwa
  module Webhooks
    # Parses LNbits invoice-payment callbacks. LNbits does not sign webhook
    # bodies by default; the verifier compares a per-invoice token supplied in
    # the webhook URL instead. Treat the callback only as a notification and
    # independently confirm payment with #check_invoice before crediting it.
    module Lnbits
      module_function

      def call(body:, headers: {}) # rubocop:disable Lint/UnusedMethodArgument
        payload = parse(body)

        Lipwa::WebhookEvent.new(
          provider: :lnbits,
          event_type: :payment,
          success: !payload.key?("paid") || payload["paid"] == true,
          provider_reference: payload.fetch("payment_hash"),
          message: payload["memo"],
          raw: payload,
          verifier: method(:verify_signature)
        )
      end

      def parse(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end

      # This verifies knowledge of a shared URL token, not authenticity of the
      # body. The ** passthrough preserves the API for a future HMAC mode.
      def verify_signature(raw: nil, expected_token: nil, provided_token: nil, **) # rubocop:disable Lint/UnusedMethodArgument
        return false unless expected_token && provided_token
        return false unless expected_token.bytesize == provided_token.bytesize

        OpenSSL.fixed_length_secure_compare(expected_token, provided_token)
      end
    end
  end
end

Lipwa::Webhook.register(:lnbits, Lipwa::Webhooks::Lnbits)
