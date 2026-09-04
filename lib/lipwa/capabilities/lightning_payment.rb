# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/lightning_payment_contract"
require_relative "../contracts/lightning_payment_check_contract"

module Lipwa
  module Capabilities
    # Sends and reconciles outbound Lightning payments. This capability is
    # deliberately separate from LightningInvoice because spending requires a
    # materially more privileged credential than receiving.
    module LightningPayment
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :lightning_payment

      PATH = "/api/v1/payments"
      PAY_CONTRACT = Lipwa::Contracts::LightningPaymentContract.new
      CHECK_CONTRACT = Lipwa::Contracts::LightningPaymentCheckContract.new

      def pay_invoice(bolt11:)
        validation = PAY_CONTRACT.call(bolt11: bolt11)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_pay_invoice(validation.to_h)
      end

      def check_payment(payment_hash:)
        validation = CHECK_CONTRACT.call(payment_hash: payment_hash)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_check_payment(validation.to_h)
      end

      private

      def perform_pay_invoice(params)
        response = lightning_payment_http.post(PATH, body: { out: true, bolt11: params[:bolt11] })
        Success(payment_response(response.body))
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_check_payment(params)
        response = lightning_payment_http.get("#{PATH}/#{params[:payment_hash]}")
        Success(payment_response(response.body, payment_hash: params[:payment_hash]))
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def payment_response(payload, payment_hash: nil)
        Lipwa::Response.new(
          success: payment_successful?(payload),
          provider_reference: payment_hash || payload["payment_hash"],
          message: payload["detail"] || payload["message"],
          raw: payload
        )
      end

      def payment_successful?(payload)
        payload["paid"] == true || payload["status"].to_s.casecmp?("success")
      end

      # Gateways with distinct spending credentials override this method.
      def lightning_payment_http
        http
      end
    end
  end
end
