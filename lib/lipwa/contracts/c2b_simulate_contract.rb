# frozen_string_literal: true

require "dry/validation"
require_relative "../money"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::C2B#simulate is called
    # with, before any network call is made. Validates the capability's
    # own params, not the raw Daraja wire payload.
    class C2bSimulateContract < Dry::Validation::Contract
      COMMAND_IDS = %w[CustomerPayBillOnline CustomerBuyGoodsOnline].freeze

      schema do
        required(:amount).filled
        required(:phone_number).filled(:string)
        required(:bill_ref_number).filled(:string)
        required(:command_id).filled(:string)
      end

      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be KES") if value.currency != "KES"
        key.failure("must be greater than zero") if value.amount <= 0
      end

      rule(:phone_number) do
        key.failure("must be a Safaricom MSISDN, e.g. 254712345678") unless value.match?(/\A254[17]\d{8}\z/)
      end

      rule(:bill_ref_number) do
        key.failure("must be 20 characters or fewer") if value.length > 20
      end

      rule(:command_id) do
        key.failure("must be one of #{COMMAND_IDS.join(", ")}") unless COMMAND_IDS.include?(value)
      end
    end
  end
end
