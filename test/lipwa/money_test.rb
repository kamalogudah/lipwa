# frozen_string_literal: true

require "test_helper"
require "bigdecimal"

class MoneyTest < Minitest::Test
  def test_defaults_currency_to_kes
    money = Lipwa::Money.new(amount: 100)
    assert_equal "KES", money.currency
  end

  def test_addition_of_same_currency
    a = Lipwa::Money.new(amount: 100, currency: "KES")
    b = Lipwa::Money.new(amount: 50, currency: "KES")
    assert_equal 150, (a + b).amount
  end

  def test_coerces_decimal_amount_without_float_rounding
    money = Lipwa::Money.new(amount: "10.25", currency: "KES")

    assert_instance_of BigDecimal, money.amount
    assert_equal BigDecimal("10.25"), money.amount
  end

  def test_decimal_addition_is_exact
    a = Lipwa::Money.new(amount: "0.1", currency: "KES")
    b = Lipwa::Money.new(amount: "0.2", currency: "KES")

    assert_equal BigDecimal("0.3"), (a + b).amount
  end

  def test_addition_raises_on_currency_mismatch
    a = Lipwa::Money.new(amount: 100, currency: "KES")
    b = Lipwa::Money.new(amount: 50, currency: "UGX")
    assert_raises(ArgumentError) { a + b }
  end

  def test_subtraction_of_same_currency
    a = Lipwa::Money.new(amount: "100.50", currency: "KES")
    b = Lipwa::Money.new(amount: "40.25", currency: "KES")

    assert_equal BigDecimal("60.25"), (a - b).amount
  end

  def test_subtraction_raises_on_currency_mismatch
    a = Lipwa::Money.new(amount: 100, currency: "KES")
    b = Lipwa::Money.new(amount: 50, currency: "UGX")

    assert_raises(ArgumentError) { a - b }
  end

  def test_rejects_a_non_money_operand
    money = Lipwa::Money.new(amount: 100, currency: "KES")

    assert_raises(TypeError) { money + 10 }
  end

  def test_multiplies_by_a_numeric_scalar
    money = Lipwa::Money.new(amount: "12.50", currency: "KES")

    result = money * "1.5"

    assert_equal BigDecimal("18.75"), result.amount
    assert_equal "KES", result.currency
  end

  def test_divides_by_a_numeric_scalar
    money = Lipwa::Money.new(amount: 10, currency: "KES")

    assert_equal BigDecimal("2.5"), (money / 4).amount
  end

  def test_division_by_zero_raises
    money = Lipwa::Money.new(amount: 10, currency: "KES")

    assert_raises(ZeroDivisionError) { money / 0 }
  end

  def test_rejects_negative_arithmetic_results
    a = Lipwa::Money.new(amount: 10, currency: "KES")
    b = Lipwa::Money.new(amount: 20, currency: "KES")

    assert_raises(Dry::Struct::Error) { a - b }
    assert_raises(Dry::Struct::Error) { a * -1 }
  end

  def test_compares_amounts_in_the_same_currency
    lower = Lipwa::Money.new(amount: "9.99", currency: "KES")
    higher = Lipwa::Money.new(amount: "10.00", currency: "KES")

    assert_operator lower, :<, higher
  end

  def test_comparison_raises_on_currency_mismatch
    kes = Lipwa::Money.new(amount: 10, currency: "KES")
    usd = Lipwa::Money.new(amount: 10, currency: "USD")

    assert_raises(ArgumentError) { kes < usd }
  end

  def test_zero_predicate
    assert_predicate Lipwa::Money.new(amount: 0), :zero?
    refute_predicate Lipwa::Money.new(amount: "0.01"), :zero?
  end

  def test_rejects_negative_amounts
    assert_raises(Dry::Struct::Error) { Lipwa::Money.new(amount: -1, currency: "KES") }
  end

  def test_rejects_invalid_currency_format
    assert_raises(Dry::Struct::Error) { Lipwa::Money.new(amount: 1, currency: "kes") }
  end

  def test_to_s
    money = Lipwa::Money.new(amount: "100.50", currency: "KES")
    assert_equal "100.5 KES", money.to_s
  end
end
