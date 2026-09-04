# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/card_transaction_contract"

module Lipwa
  module Capabilities
    # Cancels an authorization which has not completed.
    module Void
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :void

      CONTRACT = Lipwa::Contracts::CardTransactionContract.new

      def void(authorization:, idempotency_key: nil)
        validation = CONTRACT.call(authorization: authorization)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_void(validation.to_h, idempotency_key)
      end
    end
  end
end
