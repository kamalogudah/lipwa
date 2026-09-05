module Api
  module V1
    class RefundsController < ApplicationController
      # POST /api/v1/refunds
      # { "transaction_id": "OEI2AK4Q16", "amount": 10000, "remarks": "Missing item" }
      def create
        transaction = Transaction.create!(
          kind: "refund",
          status: "pending",
          amount_cents: params[:amount],
          currency: params.fetch(:currency, "KES"),
          account_reference: params[:transaction_id]
        )

        result = Lipwa.gateway(:mpesa).refund(
          transaction_id: params[:transaction_id],
          amount: Lipwa::Money.new(amount: params[:amount].to_i, currency: params.fetch(:currency, "KES")),
          remarks: params[:remarks],
          result_url: webhooks_mpesa_result_url,
          queue_timeout_url: webhooks_mpesa_timeout_url,
          occasion: params[:occasion]
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
