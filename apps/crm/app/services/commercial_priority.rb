# Rubric v2 keeps three separate readings of a lead:
#   1. Commercial intent: the rubric score (ScoringCriterion), set by people.
#   2. Economic attractiveness: this service, from budget, service value,
#      competition, urgency and age.
#   3. Confidence: the share of attractiveness weight backed by real data.
#
# A factor without data is excluded, never assumed. Size thresholds only
# classify; they never discard a lead. Profitability stays "unknown" until
# internal costs, an approved rate and estimated hours all exist.
class CommercialPriority
  WEIGHTS = {
    "economic_value" => 30,
    "budget_vs_rate" => 25,
    "competition" => 20,
    "service_value" => 15,
    "urgency" => 5,
    "recency" => 5
  }.freeze
  CLASSES = %w[high medium low not_recommended].freeze
  LABELS = { "high" => "Prioridad comercial alta", "medium" => "Prioridad comercial media",
             "low" => "Prioridad comercial baja", "not_recommended" => "No recomendable" }.freeze
  HIGH_FROM = 70
  MEDIUM_FROM = 50
  MIN_CONFIDENCE = 0.5
  TIER_VALUE = { "high" => 1.0, "medium" => 0.6, "low" => 0.25 }.freeze
  BAND_VALUE = { "high" => 1.0, "medium" => 0.5, "low" => 0.15 }.freeze
  BAND_LABELS = { "high" => "alto", "medium" => "medio", "low" => "bajo" }.freeze
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
    @alerts = []
  end

  def call
    check_blockers
    WEIGHTS.each_key { |key| evaluate(key) }

    evaluated_weight = @factors.sum { |f| f["weight"] }
    score = evaluated_weight.zero? ? 0 : (@factors.sum { |f| f["weight"] * f["fraction"] } * 100.0 / evaluated_weight).round
    confidence = (evaluated_weight / 100.0).round(2)
    priority, capped = classify(score, confidence)

    Result.new(priority: priority, score: score, confidence: confidence, breakdown: {
      "intent" => intent_reading, "size_band" => size_band, "profitability" => profitability,
      "factors" => @factors, "excluded" => @excluded, "blockers" => @blockers, "alerts" => @alerts,
      "capped_by_confidence" => capped
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

    # Only facts that make the work impossible or out of policy. Money never blocks.
    def check_blockers
      intent = intent_score
      @blockers << "Sin intención de contratación" if intent && intent.points.zero?
      @blockers << "Fuera del catálogo de servicios" if lead.services.empty?
      @blockers << "Mercado no atendido (#{lead.country.iso2})" if lead.country && !lead.country.target_market
      @blockers << "Publicación cerrada" if lead.listing_closed
      @blockers << "Plazo para ofertar vencido" if lead.deadline_at && lead.deadline_at < @now
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

    def factor_economic_value
      return [ nil, "Sin presupuesto publicado" ] unless budget?
      return [ nil, "Sin umbrales de clasificación para #{lead.budget_currency}" ] unless threshold

      band = size_band
      reference = band == "high" ? threshold.high_from_amount : threshold.medium_from_amount
      comparison = band == "low" ? "debajo de" : "desde"
      [ BAND_VALUE.fetch(band), "Tamaño #{BAND_LABELS[band]} (máximo publicado #{comparison} #{reference})" ]
    end

    def factor_budget_vs_rate
      return [ nil, "Sin presupuesto publicado" ] unless budget?

      rate = rate_for_budget
      return [ nil, "Sin tarifa aprobada en #{lead.budget_currency} para estos servicios" ] unless rate

      cost = price_floor(rate)
      return [ nil, "Tarifa por hora: faltan horas estimadas" ] if cost.nil?
      return [ nil, "Tarifa mensual: comparar a mano" ] if cost == :monthly

      minimum = Money.from_cents(cost, rate.currency)
      if lead.budget_max_cents < cost
        @alerts << "El presupuesto publicado no cubre la tarifa mínima aprobada (#{minimum}); revisar alcance antes de ofertar"
        [ 0, "El máximo publicado no cubre la tarifa mínima (#{minimum})" ]
      elsif lead.budget_min_cents >= cost
        [ 1, "Todo el rango cubre la tarifa mínima (#{minimum})" ]
      else
        [ 0.5, "Solo parte del rango cubre la tarifa mínima (#{minimum})" ]
      end
    end

    def factor_competition
      count = lead.competition_count
      return [ nil, "Competencia no registrada" ] if count.nil?

      fraction = count <= 10 ? 1 : count <= 30 ? 0.66 : count <= 100 ? 0.33 : 0
      [ fraction, "#{count} propuestas visibles" ]
    end

    def factor_service_value
      service = best_service
      return [ nil, "Sin servicio del catálogo" ] unless service

      value = TIER_VALUE.fetch(service.value_tier)
      value = [ value + RECURRING_BONUS, 1.0 ].min if service.recurring
      [ value, "#{service.name}: valor #{service.value_tier}#{' con potencial recurrente' if service.recurring}" ]
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

    # The CRM has no internal cost data yet, so profitability cannot be known.
    def profitability
      missing = [ "costos internos verificables" ]
      missing << "tarifa aprobada en la moneda del presupuesto" unless budget? && rate_for_budget
      missing << "horas estimadas" unless lead.estimated_hours
      { "status" => "unknown", "missing" => missing }
    end

    def intent_reading
      return { "status" => "not_scored" } unless lead.score

      { "status" => "scored", "score" => lead.score, "band" => lead.score_band, "version" => lead.scoring_version }
    end

    def size_band
      budget? && threshold ? threshold.band_for(lead.budget_max_cents) : nil
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

    def price_floor(rate)
      case rate.unit
      when "project" then rate.min_cents
      when "hour" then lead.estimated_hours && rate.min_cents * lead.estimated_hours
      else :monthly
      end
    end
end
