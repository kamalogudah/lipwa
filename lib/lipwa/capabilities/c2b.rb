# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/c2b_register_urls_contract"
require_relative "../contracts/c2b_simulate_contract"

module Lipwa
  module Capabilities
    # Customer To Business (C2B): registers the validation/confirmation
    # webhook URLs Daraja calls when a customer pays a paybill/till
    # directly (outside STK Push), and — sandbox only — simulates such
    # a payment for testing. The actual payment notification arrives
    # later at the registered confirmation URL; these calls only manage
    # that registration and drive the sandbox simulator.
    module C2B
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :c2b

      REGISTER_URLS_PATH = "/mpesa/c2b/v1/registerurl"
      SIMULATE_PATH = "/mpesa/c2b/v1/simulate"

      REGISTER_URLS_CONTRACT = Lipwa::Contracts::C2bRegisterUrlsContract.new
      SIMULATE_CONTRACT = Lipwa::Contracts::C2bSimulateContract.new

      def register_urls(validation_url:, confirmation_url:, response_type: "Completed", idempotency_key: nil)
        validation = REGISTER_URLS_CONTRACT.call(
          validation_url: validation_url,
          confirmation_url: confirmation_url,
          response_type: response_type
        )
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_register_urls(validation.to_h, idempotency_key)
      end

      # Sandbox-only: triggers a simulated C2B payment so the
      # registered validation/confirmation URLs can be exercised
      # without a real customer transaction.
      def simulate(amount:, phone_number:, bill_ref_number:, command_id: "CustomerPayBillOnline",
                   idempotency_key: nil)
        validation = SIMULATE_CONTRACT.call(
          amount: amount,
          phone_number: phone_number,
          bill_ref_number: bill_ref_number,
          command_id: command_id
        )
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_simulate(validation.to_h, idempotency_key)
      end

      private

      def perform_register_urls(params, idempotency_key)
        response = http.post(REGISTER_URLS_PATH, body: register_urls_body(params), idempotency_key: idempotency_key)

        build_c2b_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def register_urls_body(params)
        {
          ShortCode: config.shortcode,
          ResponseType: params[:response_type],
          ConfirmationURL: params[:confirmation_url],
          ValidationURL: params[:validation_url]
        }
      end

      def perform_simulate(params, idempotency_key)
        response = http.post(SIMULATE_PATH, body: simulate_body(params), idempotency_key: idempotency_key)

        build_c2b_response(response.body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def simulate_body(params)
        {
          ShortCode: config.shortcode,
          CommandID: params[:command_id],
          Amount: params[:amount].amount,
          Msisdn: params[:phone_number],
          BillRefNumber: params[:bill_ref_number]
        }
      end

      def build_c2b_response(body)
        Success(Lipwa::Response.new(
                  success: body["ResponseCode"] == "0",
                  provider_reference: body["ConversationID"] || body["OriginatorConversationID"] ||
                    body["OriginatorCoversationID"],
                  message: body["ResponseDescription"] || body["errorMessage"],
                  code: (body["ResponseCode"] || body["errorCode"])&.to_s,
                  raw: body
                ))
      end
    end
  end
end
