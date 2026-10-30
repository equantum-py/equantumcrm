# Presentation helpers for the lead page: turn stored analysis data into
# short commercial sentences. They never change what is stored.
module LeadsHelper
  def analysis_summary(analysis)
    output = analysis.output
    services = Service.where(key: analysis.service_keys).pluck(:name)
    intent = analysis.criteria.find { |c| c["key"] == "explicit_intent" }
    parts = []
    parts << (services.any? ? "Encaja con #{services.to_sentence}." : "No encaja con servicios del catálogo.")
    if intent
      parts << (intent["points"].to_i.positive? ? "Hay intención de contratar: #{intent['justification'].to_s.downcase_first}." : "No muestra intención de contratar.")
    end
    if (country = Country.find_by(iso2: output["country"].to_s.upcase))
      parts << "País probable: #{country.name}."
    end
    if (budget = output["budget"]).is_a?(Hash)
      parts << "Presupuesto leído: #{Money.formatted(budget['min_cents'], budget['currency'])} – #{Money.formatted(budget['max_cents'], budget['currency'])}."
    end
    parts.join(" ")
  end

  def analysis_points(analysis) = analysis.criteria.sum { |c| c["points"].to_i }

  def criterion_name(key)
    @criterion_names ||= ScoringCriterion.pluck(:key, :name).to_h
    @criterion_names.fetch(key, key)
  end

  def basis_label(basis) = basis == "verified" ? "Verificado" : "Inferido"

  def lead_budget_label(lead)
    if lead.budget_currency
      lead.budget_min_cents == lead.budget_max_cents ? lead.budget_min_amount.to_s : "#{lead.budget_min_amount} – #{lead.budget_max_amount}"
    else
      lead.published_budget_text.presence || "No publicado"
    end
  end

  def qualify_blockers(lead)
    reasons = []
    reasons << "verificar la fuente" unless lead.verification_status == "verified"
    reasons << "completar la puntuación" unless lead.score_complete?
    reasons
  end
end
