# Authorized price ranges. The only valid source of prices for proposals.
class ServiceRate < ApplicationRecord
  include Auditable

  UNITS = %w[project hour month].freeze

  belongs_to :service
  belongs_to :country, optional: true
  belongs_to :approved_by, class_name: "User"

  validates :currency, inclusion: { in: %w[PYG CLP COP EUR USD] }
  validates :unit, inclusion: { in: UNITS }
  validates :min_cents, :max_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :valid_from, :approved_at, presence: true
  validate :range_is_ordered
  validate :validity_is_ordered

  scope :effective_on, ->(date) { where(valid_from: ..date).where("valid_until IS NULL OR valid_until >= ?", date) }

  # Country-specific rate first, then the general one. nil means "precio pendiente".
  def self.current_for(service, country, on: Date.current)
    rates = effective_on(on).where(service: service).order(valid_from: :desc)
    (country && rates.find_by(country: country)) || rates.find_by(country: nil)
  end

  def min_amount = Money.from_cents(min_cents, currency)
  def max_amount = Money.from_cents(max_cents, currency)

  def min_amount=(value)
    self.min_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  def max_amount=(value)
    self.max_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  private
    def range_is_ordered
      return if min_cents.nil? || max_cents.nil?

      errors.add(:max_cents, "debe ser mayor o igual al mínimo") if max_cents < min_cents
    end

    def validity_is_ordered
      return if valid_until.nil? || valid_from.nil?

      errors.add(:valid_until, "debe ser posterior al inicio de vigencia") if valid_until < valid_from
    end
end
