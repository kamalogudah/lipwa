# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/disbursement_contract"

module Lipwa
  module Capabilities
    # Disburses funds from the gateway's shortcode to a customer (B2C —
    # salary/promotion/business payments to an MSISDN) or another
    # business (B2B — paybill/till settlement), driven by `command_id`
    # rather than two separate methods, per the target #disburse API.
    # Unlike StkPush/C2B, Daraja requires a SecurityCredential — the
    # initiator password RSA-encrypted with Safaricom's public
    # certificate — computed fresh on every call since PKCS#1 padding is
    # randomized.
    module Disbursement
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :disbursement

      B2C_PATH = "/mpesa/b2c/v1/paymentrequest"
      B2B_PATH = "/mpesa/b2b/v1/paymentrequest"
      B2C_COMMAND_IDS = Lipwa::Contracts::DisbursementContract::B2C_COMMAND_IDS
      B2B_COMMAND_IDS = Lipwa::Contracts::DisbursementContract::B2B_COMMAND_IDS

      CONTRACT = Lipwa::Contracts::DisbursementContract.new

      # rubocop:disable Metrics/ParameterLists
      def disburse(command_id:, amount:, party_b:, remarks:, result_url:, queue_timeout_url:, occasion: nil,
                   account_reference: nil, idempotency_key: nil)
        args = { command_id: command_id, amount: amount, party_b: party_b, remarks: remarks,
                 result_url: result_url, queue_timeout_url: queue_timeout_url,
                 occasion: occasion, account_reference: account_reference }
        validate_and_disburse(args, idempotency_key)
      end
      # rubocop:enable Metrics/ParameterLists

      private

      def validate_and_disburse(args, idempotency_key)
        validation = CONTRACT.call(args)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_disburse(validation.to_h, idempotency_key)
      end

      def perform_disburse(params, idempotency_key)
        ensure_disbursement_config_present!
        path = B2C_COMMAND_IDS.include?(params[:command_id]) ? B2C_PATH : B2B_PATH

        response = http.post(path, body: disbursement_body(params), idempotency_key: idempotency_key)

        build_disbursement_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def disbursement_body(params)
        if B2C_COMMAND_IDS.include?(params[:command_id])
          b2c_body(params)
        else
          b2b_body(params)
        end
      end

      def b2c_body(params)
        {
          InitiatorName: self.class.config.initiator_name,
          SecurityCredential: security_credential,
          CommandID: params[:command_id],
          PartyA: self.class.config.shortcode,
          PartyB: params[:party_b],
          Occasion: params[:occasion]
        }.merge(shared_disbursement_fields(params))
      end

      def b2b_body(params)
        {
          Initiator: self.class.config.initiator_name,
          SecurityCredential: security_credential,
          CommandID: params[:command_id],
          SenderIdentifierType: "4",
          RecieverIdentifierType: "4",
          PartyA: self.class.config.shortcode,
          PartyB: params[:party_b],
          AccountReference: params[:account_reference]
        }.merge(shared_disbursement_fields(params))
      end

      def shared_disbursement_fields(params)
        {
          Amount: params[:amount].amount,
          Remarks: params[:remarks],
          QueueTimeOutURL: params[:queue_timeout_url],
          ResultURL: params[:result_url]
        }
      end

      def security_credential
        Lipwa::Gateways::Mpesa::SecurityCredential.encrypt(
          self.class.config.initiator_password,
          cert: self.class.config.security_credential_cert
        )
      end

      def build_disbursement_response(body)
        Success(Lipwa::Response.new(
                  success: body["ResponseCode"] == "0",
                  provider_reference: body["ConversationID"] || body["OriginatorConversationID"] ||
                    body["OriginatorCoversationID"],
                  message: body["ResponseDescription"] || body["errorMessage"],
                  code: (body["ResponseCode"] || body["errorCode"])&.to_s,
                  raw: body
                ))
      end

      def ensure_disbursement_config_present!
        config = self.class.config
        return if config.initiator_name && config.initiator_password && config.security_credential_cert

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing initiator_name/initiator_password/security_credential_cert " \
              "— set them via .configure to use #disburse"
      end
    end
  end
end
