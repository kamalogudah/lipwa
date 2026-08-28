# frozen_string_literal: true

require "dry/types"

module Lipwa
  # Shared Dry::Types module for value objects across the gem.
  module Types
    include Dry.Types()

    # Amounts are always integers in minor currency units (e.g. cents,
    # or whole KES since M-Pesa has no subunit) to avoid float math.
    Amount = Types::Strict::Integer.constrained(gteq: 0)

    Currency = Types::Strict::String.constrained(format: /\A[A-Z]{3}\z/)

    Environment = Types::Strict::Symbol.enum(:sandbox, :production)
  end
end
