# frozen_string_literal: true

require "dry/validation"
require_relative "../money"

module Lipwa
  module Contracts
    # Validates the shared hosted-checkout request shape.
    class CardPaymentContract < Dry::Validation::Contract
      schema do
        required(:amount).filled
        required(:reference).filled(:string)
        required(:description).filled(:string)
        required(:callback_url).filled(:string)
        required(:notification_id).filled(:string)
        required(:billing_address).hash
        optional(:cancellation_url).maybe(:string)
        optional(:redirect_mode).maybe(:string)
        optional(:branch).maybe(:string)
        optional(:card_number).maybe(:string)
        optional(:cvv).maybe(:string)
        optional(:expiry_month).maybe(:string)
        optional(:expiry_year).maybe(:string)
        optional(:fullname).maybe(:string)
        optional(:phone_number).maybe(:string)
        optional(:usesecureauth).maybe(:bool)
      end

      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be greater than zero") unless value.amount.positive?
      end

      rule(:reference) do
        key.failure("must be 50 characters or fewer") if value.length > 50
        key.failure("contains unsupported characters") unless value.match?(/\A[A-Za-z0-9_.:-]+\z/)
      end

      rule(:description) { key.failure("must be 100 characters or fewer") if value.length > 100 }

      rule(:callback_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end

      rule(:cancellation_url) do
        key.failure("must be an https:// URL") if value && !value.start_with?("https://")
      end

      rule(:billing_address) do
        address = value
        unless address[:email_address] || address["email_address"] ||
               address[:phone_number] || address["phone_number"]
          key.failure("must contain an email_address or phone_number")
        end
      end
    end
  end
end
