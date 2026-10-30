class Lead < ApplicationRecord
  include Auditable

  STATUSES = %w[new researching qualified discarded converted].freeze
  VERIFICATION_STATUSES = %w[unverified verified unreachable rejected].freeze
  URGENCIES = %w[unknown low medium high].freeze
  CREATED_VIA = %w[manual api skill].freeze

  belongs_to :source
  belongs_to :country, optional: true
  belongs_to :company, optional: true
  belongs_to :owner, class_name: "User", optional: true
  has_many :lead_services, dependent: :destroy
  has_many :services, through: :lead_services
  has_many :lead_evidences, dependent: :destroy
  has_many :lead_scores, dependent: :destroy
  has_many :ai_analyses, as: :subject, dependent: :destroy
  has_many :activities, as: :subject, dependent: :destroy
  has_one :opportunity, dependent: :restrict_with_error

  before_validation :set_defaults

  validates :title, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
  validates :urgency, inclusion: { in: URGENCIES }
  validates :created_via, inclusion: { in: CREATED_VIA }
  validates :fingerprint, presence: true, uniqueness: { message: "coincide con un prospecto ya registrado" }
  validates :discard_reason, presence: true, if: -> { status == "discarded" }
  validates :budget_currency, inclusion: { in: CommercialThreshold::CURRENCIES }, allow_blank: true
  validates :competition_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :estimated_hours, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :commercial_priority, inclusion: { in: CommercialPriority::CLASSES }, allow_nil: true
  validate :budget_is_complete
  validate :original_url_is_http
  validate :published_at_not_in_future
  validate :qualification_requirements, if: -> { status == "qualified" && status_changed? }

  scope :recent, -> { order(detected_at: :desc) }

  def self.filter(params)
    scope = all
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
    scope = scope.where(source_id: params[:source_id]) if params[:source_id].present?
    scope = scope.where(owner_id: params[:owner_id]) if params[:owner_id].present?
    scope = scope.joins(:lead_services).where(lead_services: { service_id: params[:service_id] }) if params[:service_id].present?
    scope = scope.where(score_band: params[:band]) if params[:band].present?
    if params[:q].present?
      term = "%#{sanitize_sql_like(params[:q].strip)}%"
      scope = scope.where("leads.title ILIKE :t OR leads.need_summary ILIKE :t OR leads.original_url ILIKE :t", t: term)
    end
    scope
  end

  def self.fingerprint_for(source_key:, url:, text:)
    canonical = UrlCanonicalizer.canonical(url)
    basis = canonical || "#{source_key}|#{text.to_s.downcase.gsub(/[^\p{L}\p{N}]+/, ' ').squish}"
    "sha256:#{Digest::SHA256.hexdigest(basis)}"
  end

  def duplicate_of
    Lead.where.not(id: id).find_by(fingerprint: fingerprint)
  end

  # Rails owns the final score: sum of accepted criteria for the current rubric.
  def recalculate_score!
    criteria = ScoringCriterion.current.to_a
    scores = lead_scores.where(scoring_criterion: criteria).to_a
    if criteria.any? && scores.size == criteria.size
      total = scores.sum(&:points)
      update!(score: total, score_band: ScoringCriterion.band_for(total), scoring_version: criteria.first.version)
    else
      update!(score: nil, score_band: nil, scoring_version: nil)
    end
    refresh_priority!
  end

  # Stores the commercial priority. Off until rubric v2 is active.
  def refresh_priority!
    return unless RubricVersion.priority_enabled?

    result = CommercialPriority.new(self).call
    update!(commercial_priority: result.priority, priority_score: result.score, priority_confidence: result.confidence,
            priority_breakdown: result.breakdown, priority_calculated_at: Time.current)
  end

  def budget_min_amount = budget_min_cents && Money.from_cents(budget_min_cents, budget_currency)
  def budget_max_amount = budget_max_cents && Money.from_cents(budget_max_cents, budget_currency)

  def budget_min_amount=(value)
    self.budget_min_cents = value.blank? || budget_currency.blank? ? nil : Money.to_cents(value, budget_currency)
  end

  def budget_max_amount=(value)
    self.budget_max_cents = value.blank? || budget_currency.blank? ? nil : Money.to_cents(value, budget_currency)
  end

  def score_complete? = score.present?
  def convertible? = status == "qualified" && opportunity.nil?
  def to_s = title

  private
    def set_defaults
      self.detected_at ||= Time.current
      if fingerprint.blank? && source
        self.fingerprint = self.class.fingerprint_for(source_key: source.key, url: original_url, text: need_summary.presence || title)
      end
    end

    def budget_is_complete
      values = [ budget_currency.presence, budget_min_cents, budget_max_cents ]
      return if values.all?(&:nil?)

      errors.add(:budget_currency, "y ambos montos son obligatorios para registrar el presupuesto") if values.any?(&:nil?)
      errors.add(:budget_max_cents, "debe ser mayor o igual al mínimo") if budget_min_cents && budget_max_cents && budget_max_cents < budget_min_cents
    end

    def original_url_is_http
      return if original_url.blank?

      errors.add(:original_url, "debe ser una URL http(s) válida") unless UrlCanonicalizer.http_url?(original_url)
    end

    def published_at_not_in_future
      errors.add(:published_at, "no puede estar en el futuro") if published_at && published_at > 1.hour.from_now
    end

    def qualification_requirements
      errors.add(:status, "requiere fuente verificada para calificar") unless verification_status == "verified"
      errors.add(:status, "requiere puntuación completa para calificar") unless score_complete?
    end
end
