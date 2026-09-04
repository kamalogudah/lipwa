# frozen_string_literal: true

require "dry/types"

module Lipwa
  # Shared Dry::Types module for value objects across the gem.
  module Types
    include Dry.Types()

    # BigDecimal-backed amounts avoid binary floating-point errors while
    # accepting the numeric and string inputs commonly received from APIs.
    Amount = Types::Coercible::Decimal.constrained(gteq: 0)

    Currency = Types::Strict::String.constrained(format: /\A[A-Z]{3}\z/)

    Environment = Types::Strict::Symbol.enum(:sandbox, :production)
  end
end
