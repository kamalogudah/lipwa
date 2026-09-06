# frozen_string_literal: true

module Webhooks
  class JengaController < ApplicationController
    def receive
      result = Lipwa::Webhook.parse_webhook(
        provider: :jenga, body: request.raw_post,
        headers: { "Authorization" => request.headers["Authorization"] }
      )
      result.either(method(:handle_event), ->(error) { render json: { error: error.message }, status: :bad_request })
    end

    private

    def handle_event(event)
      verified = event.verify_signature(username: ENV["JENGA_WEBHOOK_USERNAME"],
                                        password: ENV["JENGA_WEBHOOK_PASSWORD"])
      WebhookEvent.create!(event_type: event.event_type, provider_reference: event.provider_reference,
                           verified: verified, success: event.success?, payload: event.raw.to_json)
      return head :forbidden unless verified

      transaction = Transaction.find_by(provider_reference: event.provider_reference)
      transaction&.update!(status: event.success? ? "completed" : "failed", error_message: event.message)
      head :ok
    end
  end
end
