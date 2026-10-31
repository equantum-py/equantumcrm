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

  # Why a computed priority is still only an estimate. The algorithm's result
  # is shown unchanged; this only decides how it is labelled.
  def priority_pending_reasons(lead, pending_analysis: nil, duplicates: [])
    reasons = []
    reasons << "fuente sin verificar" unless lead.verification_status == "verified"
    reasons << "intención sin puntuar" unless lead.score
    reasons << "análisis de IA sin aprobar" if pending_analysis
    reasons << "posible duplicado" if duplicates.any?
    reasons
  end

  def priority_short_label(priority)
    CommercialPriority::LABELS[priority].delete_prefix("Prioridad comercial ").capitalize
  end

  # An estimate keeps the class colour but gets a dashed border and the word
  # "estimada", so it never reads as an approved classification.
  def priority_badge(priority, estimated:)
    label = estimated ? "#{priority_short_label(priority)} · estimada" : priority_short_label(priority)
    style = ApplicationHelper::PRIORITY_STYLES[priority]
    outline = estimated ? "border border-dashed border-slate-400" : "ring-1"
    tag.span(label, class: "inline-block w-fit rounded px-1.5 py-0.5 text-xs font-medium #{style} #{outline}")
  end

  def qualify_blockers(lead)
    reasons = []
    reasons << "verificar la fuente" unless lead.verification_status == "verified"
    reasons << "completar la puntuación" unless lead.score_complete?
    reasons
  end
end
