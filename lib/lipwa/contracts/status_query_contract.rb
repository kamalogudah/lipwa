# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::StatusQuery#status is
    # called with, before any network call is made. PartyA and
    # IdentifierType aren't part of the schema — like Disbursement's
    # PartyA, they're always the gateway's own shortcode, not a
    # per-call param.
    class StatusQueryContract < Dry::Validation::Contract
      schema do
        required(:transaction_id).filled(:string)
        required(:remarks).filled(:string)
        required(:result_url).filled(:string)
        required(:queue_timeout_url).filled(:string)
        optional(:occasion).maybe(:string)
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
