module Api
  module V1
    class StkPushesController < ApplicationController
      # POST /api/v1/stk_pushes
      # { "amount": 100, "currency": "KES", "phone_number": "254712345678", "account_reference": "ORDER-123" }
      def create
        transaction = Transaction.create!(
          kind: "stk_push",
          status: "pending",
          amount_cents: params[:amount],
          currency: params.fetch(:currency, "KES"),
          phone_number: params[:phone_number],
          account_reference: params[:account_reference]
        )

        result = Lipwa.gateway(:mpesa).stk_push(
          amount: Lipwa::Money.new(amount: params[:amount].to_i, currency: params.fetch(:currency, "KES")),
          phone_number: params[:phone_number],
          account_reference: params[:account_reference],
          callback_url: stk_push_callback_url
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

      private

      def stk_push_callback_url
        webhooks_mpesa_stk_url
      end
    end
  end
end
