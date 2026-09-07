# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the LNbits payment hash used to look up an invoice.
    class LightningInvoiceCheckContract < Dry::Validation::Contract
      schema do
        required(:payment_hash).filled(:string)
      end

      rule(:payment_hash) do
        key.failure("contains unsupported characters") unless value.match?(/\A[A-Za-z0-9_-]+\z/)
      end
    end
  end
end
