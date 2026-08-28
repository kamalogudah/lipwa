# frozen_string_literal: true

require "dry/struct"
require_relative "types"

module Lipwa
  # Immutable representation of an amount in minor currency units.
  # KES has no subunit in practice, but we keep minor units as the
  # storage form so other currencies fit the same shape later.
  class Money < Dry::Struct
    attribute :amount, Types::Amount
    attribute :currency, Types::Currency.default("KES")

    def +(other)
      assert_same_currency!(other)
      self.class.new(amount: amount + other.amount, currency: currency)
    end

    def -(other)
      assert_same_currency!(other)
      self.class.new(amount: amount - other.amount, currency: currency)
    end

    def to_s
      "#{amount} #{currency}"
    end

    private

    def assert_same_currency!(other)
      return if currency == other.currency

      raise ArgumentError, "currency mismatch: #{currency} vs #{other.currency}"
    end
  end
end
