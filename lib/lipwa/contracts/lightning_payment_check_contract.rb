# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the payment hash used to reconcile an outbound payment.
    class LightningPaymentCheckContract < Dry::Validation::Contract
      schema do
        required(:payment_hash).filled(:string)
      end
    end
  end
end
