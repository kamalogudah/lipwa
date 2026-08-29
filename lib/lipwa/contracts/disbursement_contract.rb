# frozen_string_literal: true

require "dry/validation"
require_relative "../money"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::Disbursement#disburse is
    # called with, before any network call is made. Covers both B2C
    # (PartyB is a phone number) and B2B (PartyB is a business shortcode,
    # AccountReference required) shapes under one contract, mirroring how
    # #disburse itself dispatches on command_id rather than exposing two
    # methods.
    class DisbursementContract < Dry::Validation::Contract
      B2C_COMMAND_IDS = %w[SalaryPayment BusinessPayment PromotionPayment].freeze
      B2B_COMMAND_IDS = %w[BusinessPayBill BusinessBuyGoods MerchantToMerchantTransfer].freeze
      COMMAND_IDS = (B2C_COMMAND_IDS + B2B_COMMAND_IDS).freeze

      schema do
        required(:command_id).filled(:string)
        required(:amount).filled
        required(:party_b).filled(:string)
        required(:remarks).filled(:string)
        required(:result_url).filled(:string)
        required(:queue_timeout_url).filled(:string)
        optional(:occasion).maybe(:string)
        optional(:account_reference).maybe(:string)
      end

      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be KES") if value.currency != "KES"
        key.failure("must be greater than zero") if value.amount <= 0
      end

      rule(:command_id) do
        key.failure("must be one of #{COMMAND_IDS.join(", ")}") unless COMMAND_IDS.include?(value)
      end

      rule(:party_b, :command_id) do
        next unless B2C_COMMAND_IDS.include?(values[:command_id])

        unless values[:party_b].match?(/\A254[17]\d{8}\z/)
          key(:party_b).failure("must be a Safaricom MSISDN, e.g. 254712345678")
        end
      end

      rule(:account_reference, :command_id) do
        next unless B2B_COMMAND_IDS.include?(values[:command_id])

        if values[:account_reference].nil? || values[:account_reference].empty?
          key(:account_reference).failure("is required for B2B command IDs")
        end
      end

      rule(:result_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end

      rule(:queue_timeout_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end
    end
  end
end
