# Minimal money helpers. Amounts are stored in minor units; PYG and CLP have none.
module Money
  ZERO_DECIMAL = %w[PYG CLP].freeze

  Amount = Data.define(:cents, :currency) do
    def to_d = BigDecimal(cents) / Money.factor(currency)
    def to_s = Money.formatted(cents, currency)
  end

  module_function

  def factor(currency) = ZERO_DECIMAL.include?(currency) ? 1 : 100

  def from_cents(cents, currency) = Amount.new(cents: cents, currency: currency)

  def to_cents(value, currency)
    (BigDecimal(normalize_number(value.to_s.delete(" "))) * factor(currency)).round.to_i
  rescue ArgumentError
    nil
  end

  # Accepts "1.500.000", "1.500.000,50", "1,500,000.50" and "1500,5".
  def normalize_number(text)
    case text
    when /\A\d{1,3}(\.\d{3})+(,\d+)?\z/ then text.delete(".").tr(",", ".")
    when /\A\d{1,3}(,\d{3})+(\.\d+)?\z/ then text.delete(",")
    else text.tr(",", ".")
    end
  end

  def formatted(cents, currency)
    decimals = factor(currency) == 1 ? 0 : 2
    number = ActiveSupport::NumberHelper.number_to_delimited(
      Kernel.format("%.#{decimals}f", BigDecimal(cents) / factor(currency)), delimiter: ".", separator: ","
    )
    "#{currency} #{number}"
  end
end
