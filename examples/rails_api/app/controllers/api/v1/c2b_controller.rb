module Api
  module V1
    class C2bController < ApplicationController
      # POST /api/v1/c2b/register_urls
      def register_urls
        result = Lipwa.gateway(:mpesa).register_urls(
          validation_url: webhooks_mpesa_c2b_url,
          confirmation_url: webhooks_mpesa_c2b_url
        )

        render_result(result)
      end

      # POST /api/v1/c2b/simulate  (Daraja sandbox only)
      # { "amount": 100, "currency": "KES", "phone_number": "254712345678", "bill_ref_number": "ORDER-123" }
      def simulate
        transaction = Transaction.create!(
          kind: "c2b_simulate",
          status: "pending",
          amount_cents: params[:amount],
          currency: params.fetch(:currency, "KES"),
          phone_number: params[:phone_number],
          account_reference: params[:bill_ref_number]
        )

        result = Lipwa.gateway(:mpesa).simulate(
          amount: Lipwa::Money.new(amount: params[:amount].to_i, currency: params.fetch(:currency, "KES")),
          phone_number: params[:phone_number],
          bill_ref_number: params[:bill_ref_number]
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
