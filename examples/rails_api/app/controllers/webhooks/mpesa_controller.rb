module Webhooks
  class MpesaController < ApplicationController
    # POST /webhooks/mpesa/stk        (STK Push result callback)
    # POST /webhooks/mpesa/c2b        (C2B validation/confirmation)
    # POST /webhooks/mpesa/result     (B2C/B2B/refund result callback)
    # POST /webhooks/mpesa/timeout    (B2C/B2B/refund queue timeout callback)
    def receive
      body = request.raw_post
      result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: body)

      result.either(
        method(:handle_event),
        ->(error) { render json: { error: error.message }, status: :bad_request }
      )
    end

    private

    def handle_event(event)
      verified = event.verify_signature(source_ip: request.remote_ip)

      WebhookEvent.create!(
        event_type: event.event_type,
        provider_reference: event.provider_reference,
        verified: verified,
        success: event.success?,
        payload: event.raw.to_json
      )

      unless verified
        Rails.logger.warn("[Lipwa::Webhooks::Mpesa] rejecting callback from untrusted IP #{request.remote_ip}")
        return head :forbidden
      end

      transaction = Transaction.find_by(provider_reference: event.provider_reference)
      transaction&.update!(status: event.success? ? "completed" : "failed", error_message: event.message)

      head :ok
    end
  end
end
