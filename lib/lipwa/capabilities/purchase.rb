# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/card_payment_contract"

module Lipwa
  module Capabilities
    # Creates a payment which is collected in the provider checkout flow.
    module Purchase
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :purchase

      CONTRACT = Lipwa::Contracts::CardPaymentContract.new

      def purchase(**params)
        idempotency_key = params.delete(:idempotency_key)
        validation = CONTRACT.call(params)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_purchase(validation.to_h, idempotency_key)
      end
    end
  end
end
