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
    end
  end
end
