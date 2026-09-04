# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/lightning_invoice_contract"
require_relative "../contracts/lightning_invoice_check_contract"

module Lipwa
  module Capabilities
    # Creates and checks LNbits Lightning invoices. Amounts passed to
    # #create_invoice are integer satoshis; they intentionally do not use
    # Lipwa::Money because BTC/sats are outside the ISO-4217 money model.
    module LightningInvoice
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :lightning_invoice

      PATH = "/api/v1/payments"
      CREATE_CONTRACT = Lipwa::Contracts::LightningInvoiceContract.new
      CHECK_CONTRACT = Lipwa::Contracts::LightningInvoiceCheckContract.new

      def create_invoice(amount_sats:, memo: nil, expiry: nil, webhook_url: nil)
        validation = CREATE_CONTRACT.call(
          amount_sats: amount_sats, memo: memo, expiry: expiry, webhook_url: webhook_url
        )
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_create_invoice(validation.to_h)
      end

      def check_invoice(payment_hash:)
        validation = CHECK_CONTRACT.call(payment_hash: payment_hash)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_check_invoice(validation.to_h)
      end

      private

      def perform_create_invoice(params)
        response = http.post(PATH, body: lightning_invoice_body(params))

        Success(Lipwa::Response.new(
                  success: true,
                  provider_reference: response.body["payment_hash"],
                  raw: response.body
                ))
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def perform_check_invoice(params)
        response = http.get("#{PATH}/#{params[:payment_hash]}")

        Success(Lipwa::Response.new(
                  success: response.body["paid"] == true,
                  provider_reference: params[:payment_hash],
                  raw: response.body
                ))
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def lightning_invoice_body(params)
        {
          out: false,
          amount: params[:amount_sats],
          memo: params[:memo],
          expiry: params[:expiry],
          webhook: params[:webhook_url]
        }.compact
      end
    end
  end
end
