# frozen_string_literal: true

require_relative "../webhook"

module Lipwa
  module Webhooks
    # Normalizes Co-op Bank transaction callbacks into WebhookEvent.
    module CoopBank
      module_function

      def call(body:, headers: {}) # rubocop:disable Lint/UnusedMethodArgument
        payload = body.is_a?(String) ? JSON.parse(body) : body
        code = payload["MessageCode"]

        Lipwa::WebhookEvent.new(
          provider: :coop_bank,
          event_type: :transaction_status,
          success: code.to_s == "0",
          provider_reference: payload["MessageReference"]&.to_s,
          message: payload["MessageDescription"]&.to_s,
          raw: payload
        )
      end
    end
  end
end

Lipwa::Webhook.register(:coop_bank, Lipwa::Webhooks::CoopBank)
