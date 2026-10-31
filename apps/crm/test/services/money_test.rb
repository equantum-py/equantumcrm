require "test_helper"

class MoneyTest < ActiveSupport::TestCase
  test "zero-decimal currencies store whole units" do
    assert_equal 1_500_000, Money.to_cents("1500000", "PYG")
    assert_equal "PYG 1.500.000", Money.formatted(1_500_000, "PYG")
  end

  test "two-decimal currencies accept comma or dot" do
    assert_equal 120_050, Money.to_cents("1200,5", "EUR")
    assert_equal "EUR 1.200,50", Money.formatted(120_050, "EUR")
  end

  test "accepts thousands separators in the Spanish and English styles" do
    assert_equal 1_500_000, Money.to_cents("1.500.000", "PYG")
    assert_equal 150_000_050, Money.to_cents("1.500.000,50", "EUR")
    assert_equal 150_000_050, Money.to_cents("1,500,000.50", "USD")
    assert_equal 1_250, Money.to_cents("12.50", "USD")
  end

  test "invalid input yields nil" do
    assert_nil Money.to_cents("abc", "EUR")
  end
end
