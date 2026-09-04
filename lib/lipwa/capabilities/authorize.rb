# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/card_payment_contract"

module Lipwa
  module Capabilities
    # Creates a provider authorization flow without exposing card data.
    module Authorize
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :authorize

      CONTRACT = Lipwa::Contracts::CardPaymentContract.new

      def authorize(**params)
        idempotency_key = params.delete(:idempotency_key)
        validation = CONTRACT.call(params)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_authorize(validation.to_h, idempotency_key)
      end
    end
  end
end
