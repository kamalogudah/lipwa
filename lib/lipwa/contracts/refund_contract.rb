# frozen_string_literal: true

require "dry/validation"
require_relative "../money"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::Refund#refund is called
    # with, before any network call is made. ReceiverParty and
    # RecieverIdentifierType aren't part of the schema — like
    # StatusQuery's PartyA, they're always the gateway's own shortcode,
    # not a per-call param.
    class RefundContract < Dry::Validation::Contract
      schema do
        required(:transaction_id).filled(:string)
        required(:amount).filled
        required(:remarks).filled(:string)
        required(:result_url).filled(:string)
        required(:queue_timeout_url).filled(:string)
        optional(:occasion).maybe(:string)
      end

      rule(:amount) do
        next key.failure("must be a Lipwa::Money") unless value.is_a?(Lipwa::Money)

        key.failure("must be KES") if value.currency != "KES"
        key.failure("must be greater than zero") if value.amount <= 0
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
