class Opportunity < ApplicationRecord
  include Auditable

  belongs_to :company
  belongs_to :lead, optional: true
  belongs_to :pipeline_stage
  belongs_to :owner, class_name: "User"
  belongs_to :country, optional: true
  has_many :opportunity_services, dependent: :destroy
  has_many :services, through: :opportunity_services
  has_many :activities, as: :subject, dependent: :destroy

  before_validation :track_stage_change

  validates :name, presence: true, length: { maximum: 200 }
  validates :estimated_value_cents, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :currency, presence: true, if: -> { estimated_value_cents.present? }
  validates :currency, inclusion: { in: %w[PYG CLP COP EUR USD] }, allow_nil: true
  validates :lost_reason, presence: true, if: -> { pipeline_stage&.lost? }
  validates :lead_id, uniqueness: { allow_nil: true }

  scope :open, -> { joins(:pipeline_stage).where(pipeline_stages: { kind: "open" }) }

  def self.filter(params)
    scope = all
    scope = scope.where(owner_id: params[:owner_id]) if params[:owner_id].present?
    scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
    scope = scope.joins(:opportunity_services).where(opportunity_services: { service_id: params[:service_id] }) if params[:service_id].present?
    if params[:q].present?
      term = "%#{sanitize_sql_like(params[:q].strip)}%"
      scope = scope.joins(:company).where("opportunities.name ILIKE :t OR companies.trade_name ILIKE :t", t: term)
    end
    scope
  end

  # Value is entered in major units (e.g. 1500000 PYG or 1200.50 EUR).
  def estimated_value
    return if estimated_value_cents.nil?

    Money.from_cents(estimated_value_cents, currency)
  end

  def estimated_value=(value)
    self.estimated_value_cents = value.blank? ? nil : Money.to_cents(value, currency)
  end

  def days_in_stage
    ((Time.current - stage_changed_at) / 1.day).floor
  end

  def to_s = name

  private
    def track_stage_change
      return unless new_record? || pipeline_stage_id_changed?

      self.stage_changed_at = Time.current
      self.won_at = pipeline_stage&.won? ? Time.current : nil
      self.lost_at = pipeline_stage&.lost? ? Time.current : nil
      self.lost_reason = nil unless pipeline_stage&.lost?
    end
end
