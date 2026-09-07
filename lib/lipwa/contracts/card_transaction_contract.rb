# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates operations addressing an existing provider authorization.
    class CardTransactionContract < Dry::Validation::Contract
      schema do
        required(:authorization).filled(:string)
        optional(:amount).filled
      end

      rule(:authorization) do
        unless value.match?(/\A[A-Za-z0-9_.:-]+\z/) && !%w[. ..].include?(value)
          key.failure("contains unsupported characters")
        end
      end
    end
  end
end
