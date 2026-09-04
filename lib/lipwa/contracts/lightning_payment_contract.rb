# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates an outbound BOLT11 invoice before wallet funds can be spent.
    class LightningPaymentContract < Dry::Validation::Contract
      schema do
        required(:bolt11).filled(:string)
      end
    end
  end
end
