# frozen_string_literal: true

require "dry/validation"
require_relative "../money"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::StkPush#stk_push is
    # called with, before any network call is made. Validates the
    # capability's own params, not the raw Daraja wire payload.
    class StkPushContract < Dry::Validation::Contract
      schema do
        required(:amount).filled
        required(:phone_number).filled(:string)
        required(:account_reference).filled(:string)
        required(:callback_url).filled(:string)
        optional(:transaction_desc).maybe(:string)
      end

      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be KES") if value.currency != "KES"
        key.failure("must be greater than zero") if value.amount <= 0
      end

      rule(:phone_number) do
        key.failure("must be a Safaricom MSISDN, e.g. 254712345678") unless value.match?(/\A254[17]\d{8}\z/)
      end

      rule(:account_reference) do
        key.failure("must be 12 characters or fewer") if value.length > 12
      end

      rule(:callback_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end
    end
  end
end
