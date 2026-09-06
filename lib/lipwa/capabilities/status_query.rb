# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/status_query_contract"

module Lipwa
  module Capabilities
    # Actively queries Daraja for the outcome of a prior transaction
    # (STK Push, C2B, B2C/B2B) by its TransactionID, for the "all async
    # flows" case described in plan.md — a complement to, not a
    # replacement for, the passive webhook/result-callback path. Like
    # Disbursement, Daraja requires a SecurityCredential, and the query
    # call itself only acknowledges receipt; the actual status arrives
    # later at result_url as a third callback envelope
    # (`{"Result" => {...}}`), parsed by Lipwa::Webhooks::Mpesa as a
    # :transaction_status event.
    module StatusQuery
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :status_query

      PATH = "/mpesa/transactionstatus/v1/query"
      IDENTIFIER_TYPE = "4" # shortcode

      CONTRACT = Lipwa::Contracts::StatusQueryContract.new

      def status(transaction_id: nil, message_reference: nil, remarks: nil, result_url: nil, # rubocop:disable Metrics/ParameterLists
                 queue_timeout_url: nil, occasion: nil, idempotency_key: nil)
        validate_and_query(
          {
            transaction_id: transaction_id, message_reference: message_reference,
            remarks: remarks, result_url: result_url,
            queue_timeout_url: queue_timeout_url, occasion: occasion
          },
          idempotency_key
        )
      end

      private

      def validate_and_query(args, idempotency_key)
        validation = CONTRACT.call(args)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_status_query(validation.to_h, idempotency_key)
      end

      def perform_status_query(params, idempotency_key)
        ensure_status_query_config_present!

        response = status_query_request(params, idempotency_key)

        build_status_query_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def status_query_request(params, idempotency_key)
        http.post(PATH, body: status_query_body(params), idempotency_key: idempotency_key)
      end

      def status_query_body(params)
        {
          Initiator: config.initiator_name,
          SecurityCredential: security_credential,
          CommandID: "TransactionStatusQuery",
          TransactionID: params[:transaction_id],
          PartyA: config.shortcode,
          IdentifierType: IDENTIFIER_TYPE
        }.merge(shared_status_query_fields(params))
      end

      def shared_status_query_fields(params)
        {
          ResultURL: params[:result_url],
          QueueTimeOutURL: params[:queue_timeout_url],
          Remarks: params[:remarks],
          Occasion: params[:occasion]
        }
      end

      def security_credential
        Lipwa::Gateways::Mpesa::SecurityCredential.encrypt(
          config.initiator_password,
          cert: config.security_credential_cert
        )
      end

      def build_status_query_response(body)
        Success(Lipwa::Response.new(
                  success: body["ResponseCode"] == "0",
                  provider_reference: body["ConversationID"] || body["OriginatorConversationID"],
                  message: body["ResponseDescription"] || body["errorMessage"],
                  code: (body["ResponseCode"] || body["errorCode"])&.to_s,
                  raw: body
                ))
      end

      def ensure_status_query_config_present!
        config = self.config
        return if config.initiator_name && config.initiator_password && config.security_credential_cert

        raise Lipwa::ConfigurationError,
              "#{self.class} is missing initiator_name/initiator_password/security_credential_cert " \
              "— set them via .configure to use #status"
      end
    end
  end
end
