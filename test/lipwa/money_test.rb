# frozen_string_literal: true

require "test_helper"

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

  def test_addition_raises_on_currency_mismatch
    a = Lipwa::Money.new(amount: 100, currency: "KES")
    b = Lipwa::Money.new(amount: 50, currency: "UGX")
    assert_raises(ArgumentError) { a + b }
  end

  def test_rejects_negative_amounts
    assert_raises(Dry::Struct::Error) { Lipwa::Money.new(amount: -1, currency: "KES") }
  end

  def test_rejects_invalid_currency_format
    assert_raises(Dry::Struct::Error) { Lipwa::Money.new(amount: 1, currency: "kes") }
  end

  def test_to_s
    money = Lipwa::Money.new(amount: 100, currency: "KES")
    assert_equal "100 KES", money.to_s
  end
end
