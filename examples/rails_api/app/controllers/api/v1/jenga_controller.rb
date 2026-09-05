# frozen_string_literal: true

module Api
  module V1
    class JengaController < ApplicationController
      def transfer
        rail = params.require(:rail).to_sym
        amount = money
        source_account = params[:source_account].presence || jenga.config.source_account
        destination_account = params.require(:destination_account)
        transaction = Transaction.create!(kind: "jenga_transfer", status: "pending", rail: rail.to_s,
                                          amount_cents: amount.amount, currency: amount.currency,
                                          source_account: source_account, destination_account: destination_account,
                                          account_reference: params[:reference])

        result = jenga.transfer(
          rail: rail, amount: amount, source_account: source_account,
          destination_account: destination_account, destination_name: params[:destination_name],
          destination_bank_code: params[:destination_bank_code], biller_code: params[:biller_code],
          reference: params.require(:reference), narration: params[:narration],
          callback_url: params[:callback_url], idempotency_key: params[:idempotency_key]
        )
        render_result(result, status: :accepted,
                      on_failure: ->(error) { transaction.update!(status: "failed", error_message: error.message) }) do |response|
          transaction.update!(status: response.success? ? "accepted" : "rejected",
                               provider_reference: response.provider_reference, raw_response: response.raw.to_json)
          { transaction: transaction, provider_reference: response.provider_reference,
            success: response.success?, message: response.message, raw: response.raw }
        end
      end

      def balance
        render_result(jenga.balance(account_number: params.require(:account_number)))
      end

      def statement
        render_result(jenga.statement(account_number: params.require(:account_number),
                                      from_date: date_param(:from_date), to_date: date_param(:to_date)))
      end

      def forex
        render_result(jenga.forex_rates(currency_code: params.require(:currency_code),
                                        amount: params.require(:amount), to_currency: params.require(:to_currency),
                                        account_number: params[:account_number], country_code: params[:country_code]))
      end

      def disburse
        transaction = Transaction.create!(kind: "jenga_disbursement", status: "pending",
                                          amount_cents: params[:amount], currency: params.fetch(:currency, "KES"),
                                          phone_number: params[:party_b], account_reference: params[:account_reference])
        result = jenga.disburse(
          command_id: params.fetch(:command_id, "SalaryPayment"), amount: money,
          party_b: params.require(:party_b), remarks: params.require(:remarks),
          result_url: params[:result_url].presence || webhooks_jenga_url,
          queue_timeout_url: params[:queue_timeout_url].presence || webhooks_jenga_url,
          occasion: params[:occasion], account_reference: params[:account_reference],
          idempotency_key: params[:idempotency_key]
        )
        render_result(result, status: :accepted,
                      on_failure: ->(error) { transaction.update!(status: "failed", error_message: error.message) }) do |response|
          transaction.update!(status: response.success? ? "accepted" : "rejected",
                               provider_reference: response.provider_reference, raw_response: response.raw.to_json)
          { transaction: transaction, provider_reference: response.provider_reference,
            success: response.success?, message: response.message, raw: response.raw }
        end
      end

      private

      def jenga = @jenga ||= Lipwa.gateway(:jenga)

      def money
        Lipwa::Money.new(amount: params.require(:amount), currency: params.fetch(:currency, "KES"))
      end

      def date_param(name)
        value = params[name]
        value.present? ? Date.iso8601(value.to_s) : nil
      rescue ArgumentError
        raise Lipwa::ConfigurationError, "#{name} must be an ISO-8601 date"
      end
    end
  end
end
