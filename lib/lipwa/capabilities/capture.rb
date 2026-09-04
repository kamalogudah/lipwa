# frozen_string_literal: true

require "dry/monads"
require_relative "../capability"
require_relative "../contracts/card_transaction_contract"

module Lipwa
  module Capabilities
    # Confirms a provider authorization has completed successfully.
    module Capture
      extend Lipwa::Capability
      include Dry::Monads[:result]
      self.capability_name = :capture

      CONTRACT = Lipwa::Contracts::CardTransactionContract.new

      def capture(authorization:, amount: nil, idempotency_key: nil)
        validation = CONTRACT.call({ authorization: authorization, amount: amount }.compact)
        return Failure(Lipwa::ValidationError.new(validation)) if validation.failure?

        perform_capture(validation.to_h, idempotency_key)
      end
    end
  end
end
