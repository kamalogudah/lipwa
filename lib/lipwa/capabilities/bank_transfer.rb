# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/bank_transfer_contract"
module Lipwa
  module Capabilities
    module BankTransfer
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :bank_transfer
      TRANSFER_CONTRACT = Lipwa::Contracts::BankTransferContract.new
      ACCOUNT_CONTRACT = Lipwa::Contracts::BankAccountContract.new
      STATEMENT_CONTRACT = Lipwa::Contracts::BankStatementContract.new

      def transfer(rail:, amount:, source_account:, destination_account:, reference:, narration: nil,
                   callback_url: nil, destination_bank_code: nil, destination_name: nil, biller_code: nil,
                   idempotency_key: nil)
        args = { rail: rail, amount: amount, source_account: source_account,
                 destination_account: destination_account, reference: reference, narration: narration,
                 callback_url: callback_url, destination_bank_code: destination_bank_code,
                 destination_name: destination_name, biller_code: biller_code }
        invoke_bank_operation(TRANSFER_CONTRACT, args, idempotency_key) do |params, key|
          bank_transfer_request(params, key)
        end
      end

      def balance(account_number:, message_reference: nil, idempotency_key: nil)
        invoke_bank_operation(ACCOUNT_CONTRACT,
                              { account_number: account_number, message_reference: message_reference },
                              idempotency_key) do |params, key|
          bank_balance_request(params, key)
        end
      end

      def statement(account_number:, from_date: nil, to_date: nil, message_reference: nil,
                    idempotency_key: nil)
        args = { account_number: account_number, from_date: from_date, to_date: to_date,
                 message_reference: message_reference }
        invoke_bank_operation(STATEMENT_CONTRACT, args, idempotency_key) do |params, key|
          bank_statement_request(params, key)
        end
      end

      private

      def invoke_bank_operation(contract, args, idempotency_key)
        validation = contract.call(args)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        build_bank_response(yield(validation.to_h, idempotency_key).body)
      rescue Lipwa::GatewayError => e
        Failure(e)
      end

      def build_bank_response(body)
        code = body["ResponseCode"] || body["responseCode"] || body["Code"] || body["code"]
        reference = body["MessageReference"] || body["messageReference"] || body["TransactionReference"] || body["transactionReference"]
        message = body["ResponseMessage"] || body["responseMessage"] || body["Message"] || body["message"]
        success = code.nil? || %w[0 00 000 200 Success SUCCESS].include?(code.to_s)
        Success(Lipwa::Response.new(success: success, provider_reference: reference&.to_s,
                                    message: message&.to_s, code: code&.to_s, raw: body))
      end
    end
  end
end
