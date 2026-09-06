# frozen_string_literal: true

require "base64"
require "dry/monads"
require_relative "../capability"
require_relative "../contracts/stk_push_contract"

module Lipwa
  module Capabilities
    # Lipa Na M-Pesa Online (STK Push): pushes a payment prompt to the
    # payer's phone. The actual result arrives later via the merchant's
    # callback URL — this call only confirms Daraja accepted the request
    # (CheckoutRequestID), it is not itself the payment result.
    module StkPush
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :stk_push

      PATH = "/mpesa/stkpush/v1/processrequest"
      TRANSACTION_TYPE = "CustomerPayBillOnline"

      CONTRACT = Lipwa::Contracts::StkPushContract.new

      # rubocop:disable Metrics/ParameterLists
      def stk_push(amount:, phone_number:, account_reference:, callback_url:, transaction_desc: nil,
                   idempotency_key: nil)
        validation = CONTRACT.call(
          amount: amount,
          phone_number: phone_number,
          account_reference: account_reference,
          callback_url: callback_url,
          transaction_desc: transaction_desc || account_reference
        )
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_stk_push(validation.to_h, idempotency_key)
      end
      # rubocop:enable Metrics/ParameterLists

      private

      def perform_stk_push(params, idempotency_key)
        response = http.post(PATH, body: stk_push_body(params), idempotency_key: idempotency_key)

        build_stk_push_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def stk_push_body(params)
        config = self.config
        timestamp = Time.now.strftime("%Y%m%d%H%M%S")

        {
          BusinessShortCode: config.shortcode,
          Password: stk_push_password(config, timestamp),
          Timestamp: timestamp,
          TransactionType: TRANSACTION_TYPE,
          PartyA: params[:phone_number],
          PartyB: config.shortcode
        }.merge(stk_push_transaction_fields(params))
      end

      def stk_push_transaction_fields(params)
        {
          Amount: params[:amount].amount,
          PhoneNumber: params[:phone_number],
          CallBackURL: params[:callback_url],
          AccountReference: params[:account_reference],
          TransactionDesc: params[:transaction_desc]
        }
      end

      def stk_push_password(config, timestamp)
        Base64.strict_encode64("#{config.shortcode}#{config.passkey}#{timestamp}")
      end

      def build_stk_push_response(body)
        Success(Lipwa::Response.new(
                  success: body["ResponseCode"] == "0",
                  provider_reference: body["CheckoutRequestID"],
                  message: body["ResponseDescription"] || body["errorMessage"],
                  code: (body["ResponseCode"] || body["errorCode"])&.to_s,
                  raw: body
                ))
      end
    end
  end
end
