# Applies an accepted analysis: copies criteria into lead_scores, adds the
# proposed services and recomputes the score. Rails stays the scorer of record.
class LeadAnalysisAcceptance
  def initialize(analysis, reviewer)
    @analysis = analysis
    @lead = analysis.subject
    @reviewer = reviewer
  end

  def call
    Lead.transaction do
      criteria = ScoringCriterion.current.index_by(&:key)
      @analysis.criteria.each do |item|
        criterion = criteria[item["key"]] or next
        score = @lead.lead_scores.find_or_initialize_by(scoring_criterion: criterion)
        score.update!(points: item["points"], basis: item["basis"], justification: item["justification"], set_by: "ai_accepted")
      end

      Service.where(key: @analysis.service_keys).find_each do |service|
        @lead.lead_services.find_or_create_by!(service: service)
      end

      if (country = Country.find_by(iso2: @analysis.output["country"].to_s.upcase)) && @lead.country.nil?
        @lead.country = country
      end
      if (budget = @analysis.output["budget"]).is_a?(Hash) && @lead.budget_currency.blank?
        @lead.assign_attributes(budget_currency: budget["currency"], budget_min_cents: budget["min_cents"], budget_max_cents: budget["max_cents"])
      end
      @lead.recommended_action = @analysis.output["recommended_action"] if @lead.recommended_action.blank?
      @lead.suggested_message = @analysis.output["draft_message"] if @lead.suggested_message.blank?
      @lead.save!
      @lead.recalculate_score!

      @lead.ai_analyses.pending.where.not(id: @analysis.id).update_all(status: "superseded")
      @analysis.update!(status: "accepted", reviewed_by: @reviewer, reviewed_at: Time.current)
      AuditLog.record!(action: "ai_analysis_accepted", auditable: @lead, changeset: { "analysis_id" => @analysis.id })
    end
  end
end
