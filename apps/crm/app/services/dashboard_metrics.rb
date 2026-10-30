# Commercial KPIs computed from real records. Empty data yields zeros.
class DashboardMetrics
  attr_reader :from, :to

  def initialize(from: nil, to: nil, country_id: nil, service_id: nil, source_id: nil, owner_id: nil)
    @to = parse_date(to) || Date.current
    @from = parse_date(from) || (@to - 29.days)
    @country_id = country_id.presence
    @service_id = service_id.presence
    @source_id = source_id.presence
    @owner_id = owner_id.presence
  end

  def period = from.beginning_of_day..to.end_of_day

  def leads_detected = leads.count
  def leads_qualified = leads.where(status: %w[qualified converted]).count
  def leads_high_priority = leads.where(score_band: %w[very_high high]).count
  def pending_contact = opportunities_in_stage("Pendiente de contacto").count

  def contacted
    activities.where(kind: %w[call meeting follow_up]).where.not(completed_at: nil).distinct.count(:subject_id)
  end

  def meetings = activities.where(kind: "meeting").count
  def proposals_sent = reached_stage_count("Propuesta enviada")
  def negotiations = opportunities_in_stage("Negociación").count
  def won = opportunities.where(won_at: period).count
  def lost = opportunities.where(lost_at: period).count

  def conversion_rate
    closed = won + lost
    closed.zero? ? nil : (won * 100.0 / closed).round(1)
  end

  # Open pipeline value grouped by currency (no conversion between currencies).
  def pipeline_value_by_currency
    base_opportunities.open.where.not(estimated_value_cents: nil).group(:currency).sum(:estimated_value_cents)
      .map { |currency, cents| Money.from_cents(cents, currency) }
  end

  def stage_breakdown
    counts = base_opportunities.group(:pipeline_stage_id).count
    PipelineStage.ordered.map { |stage| [ stage, counts.fetch(stage.id, 0) ] }
  end

  def leads_by_source
    leads.joins(:source).group("sources.name").order("count_all DESC").count
  end

  def leads_by_country
    leads.left_joins(:country).group("countries.name").order("count_all DESC").count
      .transform_keys { |name| name || "Sin país" }
  end

  def overdue_activities
    scope = Activity.overdue
    scope = scope.where(owner_id: @owner_id) if @owner_id
    scope.count
  end

  private
    def parse_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end

    def leads
      scope = Lead.where(detected_at: period)
      scope = scope.where(country_id: @country_id) if @country_id
      scope = scope.where(source_id: @source_id) if @source_id
      scope = scope.where(owner_id: @owner_id) if @owner_id
      scope = scope.where(id: LeadService.where(service_id: @service_id).select(:lead_id)) if @service_id
      scope
    end

    def base_opportunities
      scope = Opportunity.all
      scope = scope.where(country_id: @country_id) if @country_id
      scope = scope.where(owner_id: @owner_id) if @owner_id
      scope = scope.where(id: OpportunityService.where(service_id: @service_id).select(:opportunity_id)) if @service_id
      scope = scope.where(lead_id: Lead.where(source_id: @source_id).select(:id)) if @source_id
      scope
    end

    def opportunities = base_opportunities

    def opportunities_in_stage(name)
      base_opportunities.joins(:pipeline_stage).where(pipeline_stages: { name: name })
    end

    def reached_stage_count(name)
      stage = PipelineStage.find_by(name: name)
      return 0 unless stage

      base_opportunities.joins(:pipeline_stage).where("pipeline_stages.position >= ?", stage.position)
        .where.not(pipeline_stages: { kind: "lost" }).where(updated_at: period).count
    end

    def activities
      scope = Activity.where(created_at: period)
      scope = scope.where(owner_id: @owner_id) if @owner_id
      scope
    end
end
