# Commercial priority (rubric v2), kept apart from the intent score.
#
# Each factor is evaluated only when its data exists. Missing data is
# excluded, never assumed: the score is normalized over the evaluated
# weight and the share of weight evaluated becomes the confidence. With low
# confidence a lead cannot be classified above "medium". Profitability is
# only evaluated against an approved rate.
class CommercialPriority
  WEIGHTS = {
    "budget_vs_rate" => 25,
    "economic_value" => 20,
    "service_value" => 15,
    "profitability" => 15,
    "competition" => 15,
    "urgency" => 5,
    "recency" => 5
  }.freeze
  CLASSES = %w[high medium low not_recommended].freeze
  LABELS = { "high" => "Prioridad comercial alta", "medium" => "Prioridad comercial media",
             "low" => "Prioridad comercial baja", "not_recommended" => "No recomendable" }.freeze
  HIGH_FROM = 70
  MEDIUM_FROM = 45
  MIN_CONFIDENCE = 0.5
  TIER_VALUE = { "high" => 1.0, "medium" => 0.6, "low" => 0.25 }.freeze
  RECURRING_BONUS = 0.3

  Result = Data.define(:priority, :score, :confidence, :breakdown) do
    def label = LABELS[priority]
  end

  def initialize(lead, on: Time.current)
    @lead = lead
    @now = on
    @factors = []
    @excluded = []
    @blockers = []
  end

  def call
    check_blockers
    WEIGHTS.each_key { |key| evaluate(key) }

    evaluated_weight = @factors.sum { |f| f["weight"] }
    score = evaluated_weight.zero? ? 0 : (@factors.sum { |f| f["weight"] * f["fraction"] } * 100.0 / evaluated_weight).round
    confidence = (evaluated_weight / 100.0).round(2)
    priority, capped = classify(score, confidence)

    Result.new(priority: priority, score: score, confidence: confidence, breakdown: {
      "factors" => @factors, "excluded" => @excluded, "blockers" => @blockers, "capped_by_confidence" => capped
    })
  end

  private
    attr_reader :lead

    def classify(score, confidence)
      return [ "not_recommended", false ] if @blockers.any?

      priority = score >= HIGH_FROM ? "high" : score >= MEDIUM_FROM ? "medium" : "low"
      return [ "medium", true ] if priority == "high" && confidence < MIN_CONFIDENCE

      [ priority, false ]
    end

    def check_blockers
      intent = intent_score
      @blockers << "Sin intención de contratación" if intent && intent.points.zero?
      @blockers << "Fuera del catálogo de servicios" if lead.services.empty?
      @blockers << "Mercado no atendido (#{lead.country.iso2})" if lead.country && !lead.country.target_market
      @blockers << "Publicación cerrada" if lead.listing_closed
      @blockers << "Plazo para ofertar vencido" if lead.deadline_at && lead.deadline_at < @now
      if budget? && threshold && lead.budget_max_cents < threshold.min_viable_cents
        @blockers << "Presupuesto por debajo del mínimo viable aprobado (#{threshold.min_viable_amount})"
      end
      if budget? && (rate = rate_for_budget) && rate.unit == "project" && lead.budget_max_cents * 2 < rate.min_cents
        @blockers << "Presupuesto menor a la mitad de la tarifa mínima aprobada (#{rate.min_amount})"
      end
    end

    def evaluate(key)
      fraction, note = send("factor_#{key}")
      if fraction.nil?
        @excluded << { "key" => key, "weight" => WEIGHTS[key], "reason" => note }
      else
        @factors << { "key" => key, "weight" => WEIGHTS[key], "fraction" => fraction.round(2),
                      "points" => (WEIGHTS[key] * fraction).round, "note" => note }
      end
    end

    def factor_budget_vs_rate
      return [ nil, "Sin presupuesto publicado" ] unless budget?

      rate = rate_for_budget
      return [ nil, "Sin tarifa aprobada en #{lead.budget_currency} para estos servicios" ] unless rate

      cost = rate_cost(rate, rate.min_cents)
      return [ nil, "Tarifa por hora: falta la estimación de horas" ] if cost.nil?
      return [ nil, "Tarifa mensual: comparar a mano" ] if cost == :monthly

      minimum = Money.from_cents(cost, rate.currency)
      if lead.budget_max_cents < cost
        [ 0, "El presupuesto máximo no cubre la tarifa mínima (#{minimum})" ]
      elsif lead.budget_min_cents >= cost
        [ 1, "Todo el rango cubre la tarifa mínima (#{minimum})" ]
      else
        [ 0.5, "Solo parte del rango cubre la tarifa mínima (#{minimum})" ]
      end
    end

    def factor_economic_value
      return [ nil, "Sin presupuesto publicado" ] unless budget?
      return [ nil, "Sin umbrales aprobados para #{lead.budget_currency}" ] unless threshold

      if lead.budget_max_cents >= threshold.high_value_cents
        [ 1, "Alcanza el umbral de alto valor (#{threshold.high_value_amount})" ]
      elsif lead.budget_max_cents >= threshold.min_viable_cents
        [ 0.5, "Entre el mínimo viable y el alto valor" ]
      else
        [ 0, "Por debajo del mínimo viable (#{threshold.min_viable_amount})" ]
      end
    end

    def factor_service_value
      service = best_service
      return [ nil, "Sin servicio del catálogo" ] unless service

      value = TIER_VALUE.fetch(service.value_tier)
      value = [ value + RECURRING_BONUS, 1.0 ].min if service.recurring
      [ value, "#{service.name}: valor #{service.value_tier}#{' con potencial recurrente' if service.recurring}" ]
    end

    def factor_profitability
      return [ nil, "Sin presupuesto publicado" ] unless budget?

      rate = rate_for_budget
      return [ nil, "No se estima rentabilidad sin tarifa aprobada" ] unless rate

      floor = rate_cost(rate, rate.min_cents)
      target = rate_cost(rate, rate.max_cents)
      return [ nil, "No se estima rentabilidad sin horas estimadas" ] if floor.nil?
      return [ nil, "Tarifa mensual: estimar a mano" ] if floor == :monthly

      midpoint = (lead.budget_min_cents + lead.budget_max_cents) / 2
      if midpoint >= target
        [ 1, "El punto medio del presupuesto alcanza la tarifa máxima aprobada" ]
      elsif midpoint >= (floor + target) / 2
        [ 0.6, "El punto medio supera el centro del rango aprobado" ]
      elsif midpoint >= floor
        [ 0.3, "El punto medio apenas cubre la tarifa mínima" ]
      else
        [ 0, "El punto medio no cubre la tarifa mínima" ]
      end
    end

    def factor_competition
      count = lead.competition_count
      return [ nil, "Competencia no registrada" ] if count.nil?

      fraction = count <= 10 ? 1 : count <= 30 ? 0.66 : count <= 100 ? 0.33 : 0
      [ fraction, "#{count} propuestas visibles" ]
    end

    def factor_urgency
      fraction = { "high" => 1, "medium" => 0.6, "low" => 0.3 }[lead.urgency]
      fraction ? [ fraction, "Urgencia #{lead.urgency}" ] : [ nil, "Urgencia no indicada" ]
    end

    def factor_recency
      return [ nil, "Fecha de publicación desconocida" ] unless lead.published_at

      days = ((@now - lead.published_at) / 1.day).floor
      fraction = days <= 2 ? 1 : days <= 7 ? 0.66 : days <= 30 ? 0.33 : 0
      [ fraction, "Publicado hace #{days} día(s)" ]
    end

    def intent_score
      criterion = ScoringCriterion.current.find_by(key: "explicit_intent")
      criterion && lead.lead_scores.find_by(scoring_criterion: criterion)
    end

    def budget?
      lead.budget_currency.present? && lead.budget_min_cents && lead.budget_max_cents
    end

    def threshold
      return @threshold if defined?(@threshold)

      @threshold = budget? ? CommercialThreshold.find_by(currency: lead.budget_currency) : nil
    end

    def best_service
      lead.services.max_by { |service| [ TIER_VALUE.fetch(service.value_tier), service.recurring ? 1 : 0 ] }
    end

    # Approved rate in the budget currency for the most valuable service that has one.
    def rate_for_budget
      return @rate if defined?(@rate)

      services = lead.services.sort_by { |service| -TIER_VALUE.fetch(service.value_tier) }
      @rate = services.lazy.filter_map { |service| ServiceRate.current_for(service, lead.country) }
                      .find { |rate| rate.currency == lead.budget_currency }
    end

    def rate_cost(rate, cents)
      case rate.unit
      when "project" then cents
      when "hour" then lead.estimated_hours && cents * lead.estimated_hours
      else :monthly
      end
    end
end
