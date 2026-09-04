# frozen_string_literal: true

require "dry/validation"

module Lipwa
  module Contracts
    # Validates invoice creation parameters before any network call is
    # made. Amounts are integer satoshis, not Lipwa::Money: Bitcoin is
    # not an ISO-4217 currency and this capability does no currency math.
    class LightningInvoiceContract < Dry::Validation::Contract
      schema do
        required(:amount_sats).filled(:integer)
        optional(:memo).maybe(:string)
        optional(:expiry).maybe(:integer)
        optional(:webhook_url).maybe(:string)
      end

      rule(:amount_sats) do
        key.failure("must be greater than zero") unless value.positive?
      end

      rule(:webhook_url) do
        key.failure("must be an https:// URL") if value && !value.start_with?("https://")
      end
    end
  end
end
