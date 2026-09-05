module Api
  module V1
    class DisbursementsController < ApplicationController
      # POST /api/v1/disbursements
      # B2C: { "command_id": "SalaryPayment", "amount": 500000, "party_b": "254712345678", "remarks": "August salary" }
      # B2B: { "command_id": "BusinessPayBill", "amount": 1000000, "party_b": "600000", "remarks": "Supplier settlement",
      #        "account_reference": "INV-2026-08-001" }
      def create
        transaction = Transaction.create!(
          kind: "disbursement",
          status: "pending",
          amount_cents: params[:amount],
          currency: params.fetch(:currency, "KES"),
          party_b: params[:party_b],
          account_reference: params[:account_reference]
        )

        result = Lipwa.gateway(:mpesa).disburse(
          command_id: params[:command_id],
          amount: Lipwa::Money.new(amount: params[:amount].to_i, currency: params.fetch(:currency, "KES")),
          party_b: params[:party_b],
          remarks: params[:remarks],
          result_url: webhooks_mpesa_result_url,
          queue_timeout_url: webhooks_mpesa_timeout_url,
          occasion: params[:occasion],
          account_reference: params[:account_reference]
        )

        render_result(
          result,
          status: :accepted,
          on_failure: ->(error) { transaction.update!(status: "failed", error_message: error.message) }
        ) do |response|
          transaction.update!(
            status: response.success? ? "accepted" : "rejected",
            provider_reference: response.provider_reference,
            raw_response: response.raw.to_json
          )
          { transaction: transaction, provider_reference: response.provider_reference, message: response.message }
        end
      end
    end
  end
end
