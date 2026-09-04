# frozen_string_literal: true

require "dry/struct"
require_relative "types"

module Lipwa
  # Immutable, decimal representation of an amount in one currency.
  class Money < Dry::Struct
    include Comparable

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

    def *(other)
      self.class.new(amount: amount * decimal_scalar(other), currency: currency)
    end

    def /(other)
      divisor = decimal_scalar(other)
      raise ZeroDivisionError, "divided by 0" if divisor.zero?

      self.class.new(amount: amount / divisor, currency: currency)
    end

    def <=>(other)
      return nil unless other.is_a?(self.class)

      assert_same_currency!(other)
      amount <=> other.amount
    end

    def zero?
      amount.zero?
    end

    def to_s
      "#{amount.to_s("F")} #{currency}"
    end

    private

    def assert_same_currency!(other)
      raise TypeError, "expected #{self.class}, got #{other.class}" unless other.is_a?(self.class)
      return if currency == other.currency

      raise ArgumentError, "currency mismatch: #{currency} vs #{other.currency}"
    end

    def decimal_scalar(value)
      Types::Coercible::Decimal[value]
    rescue Dry::Types::CoercionError, Dry::Types::ConstraintError
      raise TypeError, "expected a numeric scalar, got #{value.inspect}"
    end
  end
end
