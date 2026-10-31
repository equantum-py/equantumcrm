# Per-currency size bands set by Dirección: "medium from" and "high from".
# They only classify opportunities by size. They are not prices, are never
# used to quote, and never discard an opportunity by themselves.
class CommercialThreshold < ApplicationRecord
  include Auditable

  CURRENCIES = %w[PYG CLP COP EUR USD].freeze

  # Order of Dirección, 30/10/2026: initial values for simulations.
  INITIAL = {
    "USD" => [ 500, 2_000 ], "EUR" => [ 500, 2_000 ], "PYG" => [ 4_000_000, 15_000_000 ],
    "COP" => [ 2_000_000, 8_000_000 ], "CLP" => [ 500_000, 2_000_000 ]
  }.freeze
  INITIAL_REFERENCE = "Orden de Dirección del 30/10/2026 (umbrales iniciales para simulación)".freeze

  belongs_to :approved_by, class_name: "User", optional: true

  validates :currency, inclusion: { in: CURRENCIES }, uniqueness: true
  validates :medium_from_cents, :high_from_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :approved_at, :approval_reference, presence: true
  validate :range_is_ordered

  def self.load_initial!
    INITIAL.each do |currency, (medium, high)|
      find_or_create_by!(currency: currency) do |threshold|
        threshold.medium_from_cents = Money.to_cents(medium, currency)
        threshold.high_from_cents = Money.to_cents(high, currency)
        threshold.approval_reference = INITIAL_REFERENCE
        threshold.approved_at = Time.zone.parse("2026-10-30 21:02")
      end
    end
  end

  def band_for(cents)
    cents >= high_from_cents ? "high" : cents >= medium_from_cents ? "medium" : "low"
  end

  def medium_from_amount = Money.from_cents(medium_from_cents, currency)
  def high_from_amount = Money.from_cents(high_from_cents, currency)

  def medium_from_amount=(value)
    self.medium_from_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  def high_from_amount=(value)
    self.high_from_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  private
    def range_is_ordered
      return if medium_from_cents.nil? || high_from_cents.nil?

      errors.add(:high_from_cents, "debe ser mayor o igual al umbral medio") if high_from_cents < medium_from_cents
    end
end
