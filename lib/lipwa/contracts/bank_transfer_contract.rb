# frozen_string_literal: true

require "dry/validation"
require_relative "../money"
module Lipwa
  module Contracts
    class BankTransferContract < Dry::Validation::Contract
      RAILS = %i[internal rtgs pesalink bill_payment].freeze
      schema do
        required(:rail).filled(:symbol)
        required(:amount).filled
        required(:source_account).filled(:string)
        required(:destination_account).filled(:string)
        required(:reference).filled(:string)
        optional(:narration).maybe(:string)
        optional(:callback_url).maybe(:string)
        optional(:destination_bank_code).maybe(:string)
        optional(:destination_name).maybe(:string)
        optional(:biller_code).maybe(:string)
      end
      rule(:rail) { key.failure("must be one of #{RAILS.join(", ")}") unless RAILS.include?(value) }
      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be greater than zero") unless value.amount.positive?
      end
      rule(:destination_bank_code, :rail) do
        if values[:rail] == :rtgs && values[:destination_bank_code].to_s.empty?
          key(:destination_bank_code).failure("is required for RTGS transfers")
        end
      end
      rule(:biller_code, :rail) do
        if values[:rail] == :bill_payment && values[:biller_code].to_s.empty?
          key(:biller_code).failure("is required for bill payments")
        end
      end
      rule(:callback_url) { key.failure("must be an https:// URL") if value && !value.start_with?("https://") }
    end

    class BankAccountContract < Dry::Validation::Contract
      schema do
        required(:account_number).filled(:string)
        optional(:message_reference).maybe(:string)
      end
    end

    class BankStatementContract < Dry::Validation::Contract
      schema do
        required(:account_number).filled(:string)
        optional(:from_date).maybe(:date)
        optional(:to_date).maybe(:date)
        optional(:message_reference).maybe(:string)
      end
      rule(:from_date, :to_date) do
        if values[:from_date] && values[:to_date] && values[:to_date] < values[:from_date]
          key(:to_date).failure("must be on or after from_date")
        end
      end
    end
  end
end
