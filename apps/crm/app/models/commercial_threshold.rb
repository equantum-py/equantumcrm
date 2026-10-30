# Per-currency limits approved by Dirección: below min_viable a project is
# not worth bidding; at or above high_value it is a priority. No defaults.
class CommercialThreshold < ApplicationRecord
  include Auditable

  CURRENCIES = %w[PYG CLP COP EUR USD].freeze

  belongs_to :approved_by, class_name: "User"

  validates :currency, inclusion: { in: CURRENCIES }, uniqueness: true
  validates :min_viable_cents, :high_value_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :approved_at, presence: true
  validate :range_is_ordered

  def min_viable_amount = Money.from_cents(min_viable_cents, currency)
  def high_value_amount = Money.from_cents(high_value_cents, currency)

  def min_viable_amount=(value)
    self.min_viable_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  def high_value_amount=(value)
    self.high_value_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  private
    def range_is_ordered
      return if min_viable_cents.nil? || high_value_cents.nil?

      errors.add(:high_value_cents, "debe ser mayor o igual al mínimo viable") if high_value_cents < min_viable_cents
    end
end
