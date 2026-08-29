# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the kwargs Lipwa::Capabilities::C2B#register_urls is
    # called with, before any network call is made. Validates the
    # capability's own params, not the raw Daraja wire payload.
    class C2bRegisterUrlsContract < Dry::Validation::Contract
      RESPONSE_TYPES = %w[Completed Cancelled].freeze

      schema do
        required(:validation_url).filled(:string)
        required(:confirmation_url).filled(:string)
        required(:response_type).filled(:string)
      end

      rule(:validation_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end

      rule(:confirmation_url) do
        key.failure("must be an https:// URL") unless value.start_with?("https://")
      end

      rule(:response_type) do
        key.failure("must be one of #{RESPONSE_TYPES.join(", ")}") unless RESPONSE_TYPES.include?(value)
      end
    end
  end
end
