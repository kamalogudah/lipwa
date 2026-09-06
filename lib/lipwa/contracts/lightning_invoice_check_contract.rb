# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates the LNbits payment hash used to look up an invoice.
    class LightningInvoiceCheckContract < Dry::Validation::Contract
      schema do
        required(:payment_hash).filled(:string)
      end
    end
  end
end
