# Price ranges per service and country. Only approved rates are a valid
# source of prices; a new or edited rate waits for approval.
class ServiceRate < ApplicationRecord
  include Auditable

  UNITS = %w[project hour month].freeze
  STATUSES = %w[pending approved retired].freeze

  belongs_to :service
  belongs_to :country, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :approved_by, class_name: "User", optional: true

  validates :currency, inclusion: { in: %w[PYG CLP COP EUR USD] }
  validates :unit, inclusion: { in: UNITS }
  validates :status, inclusion: { in: STATUSES }
  validates :min_cents, :max_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :valid_from, presence: true
  validates :approved_by, :approved_at, presence: true, if: -> { status == "approved" }
  validate :range_is_ordered
  validate :validity_is_ordered

  scope :approved, -> { where(status: "approved") }
  scope :effective_on, ->(date) { where(valid_from: ..date).where("valid_until IS NULL OR valid_until >= ?", date) }

  # Approved, country-specific rate first, then the general one. nil means "precio pendiente".
  def self.current_for(service, country, on: Date.current)
    rates = approved.effective_on(on).where(service: service).order(valid_from: :desc)
    (country && rates.find_by(country: country)) || rates.find_by(country: nil)
  end

  def approve!(user)
    update!(status: "approved", approved_by: user, approved_at: Time.current)
  end

  # Any change to the price terms sends an approved rate back to review.
  def assign_terms(attributes)
    assign_attributes(attributes)
    return unless persisted? && status == "approved" && changed?

    self.status = "pending"
    self.approved_by = nil
    self.approved_at = nil
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
