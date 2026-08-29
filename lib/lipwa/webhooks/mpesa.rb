# frozen_string_literal: true

require_relative "../webhook"

module Lipwa
  module Webhooks
    # Parses Daraja's distinct callback shapes into a normalized
    # Lipwa::WebhookEvent:
    #
    #   * STK Push result callback — {"Body"=>{"stkCallback"=>{...}}}
    #   * Transaction Status / Disbursement result callback —
    #     {"Result"=>{...}}, delivered to the ResultURL given to
    #     Lipwa::Capabilities::StatusQuery#status (and B2C/B2B) once
    #     Daraja finishes processing the query.
    #   * C2B validation/confirmation — a flat hash (TransID, MSISDN, ...),
    #     wire-identical for both requests. Daraja's only signal for which
    #     one fired is which registered URL it hit, not the payload, so
    #     both are normalized as :c2b — callers that registered distinct
    #     validation/confirmation URLs already know which is which.
    #
    # Daraja does not sign callbacks with any HMAC/shared secret, so
    # #verify_signature checks the request's source IP against
    # Safaricom's published callback IP ranges instead of a
    # cryptographic signature.
    module Mpesa
      # Safaricom's published source IPs for STK/C2B callbacks
      # (https://developer.safaricom.co.ke/docs, "Callback IP Addresses").
      TRUSTED_IPS = %w[
        196.201.214.200 196.201.214.206 196.201.213.114 196.201.214.207
        196.201.214.208 196.201.213.44 196.201.212.127 196.201.212.138
        196.201.212.129 196.201.212.136 196.201.212.74 196.201.212.69
      ].freeze

      module_function

      def call(body:, headers: {}) # rubocop:disable Lint/UnusedMethodArgument
        payload = parse(body)
        stk = payload["Body"]&.fetch("stkCallback", nil)
        result = payload["Result"]

        return stk_event(stk) if stk
        return transaction_status_event(result) if result

        c2b_event(payload)
      end

      def parse(body)
        body.is_a?(String) ? JSON.parse(body) : body
      end

      def stk_event(stk)
        Lipwa::WebhookEvent.new(
          provider: :mpesa,
          event_type: :stk_callback,
          success: stk["ResultCode"].zero?,
          provider_reference: stk["CheckoutRequestID"],
          message: stk["ResultDesc"],
          raw: stk,
          verifier: method(:verify_signature)
        )
      end

      def transaction_status_event(result)
        Lipwa::WebhookEvent.new(
          provider: :mpesa,
          event_type: :transaction_status,
          success: result["ResultCode"].zero?,
          provider_reference: result["TransactionID"] || result["ConversationID"],
          message: result["ResultDesc"],
          raw: result,
          verifier: method(:verify_signature)
        )
      end

      # C2B callbacks only fire for an already-completed paybill/till
      # payment — there is no ResultCode to key off, so `success` is
      # unconditionally true. Accepting or rejecting the underlying
      # transaction is the app's own response to the validation request,
      # not something reflected in this event.
      def c2b_event(payload)
        Lipwa::WebhookEvent.new(
          provider: :mpesa,
          event_type: :c2b,
          success: true,
          provider_reference: payload["TransID"],
          message: nil,
          raw: payload,
          verifier: method(:verify_signature)
        )
      end

      def verify_signature(raw:, source_ip: nil, **) # rubocop:disable Lint/UnusedMethodArgument
        return false unless source_ip

        TRUSTED_IPS.include?(source_ip)
      end
    end
  end
end

Lipwa::Webhook.register(:mpesa, Lipwa::Webhooks::Mpesa)
