# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/refund_contract"

module Lipwa
  module Capabilities
    # Reverses a completed M-Pesa transaction (Daraja's Transaction
    # Reversal API) by its TransactionID. Like Disbursement and
    # StatusQuery, Daraja requires a SecurityCredential, and the reversal
    # call itself only acknowledges receipt; the actual outcome arrives
    # later at result_url as a third callback envelope
    # (`{"Result" => {...}}`), parsed generically by
    # Lipwa::Webhooks::Mpesa alongside StatusQuery/Disbursement results.
    module Refund
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :refund

      PATH = "/mpesa/reversal/v1/request"
      RECEIVER_IDENTIFIER_TYPE = "11" # organization shortcode, per Daraja's Reversal API spec

      CONTRACT = Lipwa::Contracts::RefundContract.new

      # rubocop:disable Metrics/ParameterLists
      def refund(transaction_id:, amount:, remarks:, result_url:, queue_timeout_url:, occasion: nil,
                 idempotency_key: nil)
        args = { transaction_id: transaction_id, amount: amount, remarks: remarks,
                 result_url: result_url, queue_timeout_url: queue_timeout_url, occasion: occasion }
        validate_and_refund(args, idempotency_key)
      end
      # rubocop:enable Metrics/ParameterLists

      private

      def validate_and_refund(args, idempotency_key)
        validation = CONTRACT.call(args)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_refund(validation.to_h, idempotency_key)
      end

      def perform_refund(params, idempotency_key)
        ensure_refund_config_present!

        response = http.post(PATH, body: refund_body(params), idempotency_key: idempotency_key)

        build_refund_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def refund_body(params)
        {
          Initiator: self.class.config.initiator_name,
          SecurityCredential: security_credential,
          CommandID: "TransactionReversal",
          TransactionID: params[:transaction_id],
          Amount: params[:amount].amount,
          ReceiverParty: self.class.config.shortcode,
          RecieverIdentifierType: RECEIVER_IDENTIFIER_TYPE
        }.merge(shared_refund_fields(params))
      end

      def shared_refund_fields(params)
        {
          ResultURL: params[:result_url],
          QueueTimeOutURL: params[:queue_timeout_url],
          Remarks: params[:remarks],
          Occasion: params[:occasion]
        }
      end

      def security_credential
        Lipwa::Gateways::Mpesa::SecurityCredential.encrypt(
          self.class.config.initiator_password,
          cert: self.class.config.security_credential_cert
        )
      end

      def build_refund_response(body)
        Success(Lipwa::Response.new(
                  success: body["ResponseCode"] == "0",
                  provider_reference: body["ConversationID"] || body["OriginatorConversationID"],
                  message: body["ResponseDescription"] || body["errorMessage"],
                  code: (body["ResponseCode"] || body["errorCode"])&.to_s,
                  raw: body
                ))
      end

      def ensure_refund_config_present!
        config = self.class.config
        return if config.initiator_name && config.initiator_password && config.security_credential_cert

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing initiator_name/initiator_password/security_credential_cert " \
              "— set them via .configure to use #refund"
      end
    end
  end
end
