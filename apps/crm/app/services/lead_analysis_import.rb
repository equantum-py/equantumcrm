# Parses an analysis produced outside Rails (a Claude Skill today, Prospect AI
# later) into a normalized hash. It validates shape only; nothing is applied
# to the lead until a user accepts the analysis.
class LeadAnalysisImport
  class Invalid < StandardError; end

  attr_reader :errors

  def initialize(raw)
    @raw = raw.to_s.strip
    @errors = []
  end

  def call
    data = parse
    raise Invalid, "El análisis debe ser un objeto JSON o YAML" unless data.is_a?(Hash)

    criteria_by_key = ScoringCriterion.current.index_by(&:key)
    service_keys = Service.active.pluck(:key)

    {
      "services" => Array(data["services"] || data["service_keys"]).map(&:to_s) & service_keys,
      "has_commercial_intent" => data["has_commercial_intent"],
      "country" => data["country"].presence || data["country_hint"].presence,
      "criteria" => normalize_criteria(Array(data["criteria"]), criteria_by_key),
      "recommended_action" => (data["recommended_action"] || data["recommendation"] || data["suggested_next_action"]).to_s.strip.presence,
      "draft_message" => data["draft_message"].to_s.strip.presence,
      "warnings" => Array(data["warnings"]).map(&:to_s) + errors
    }
  end

  private
    def parse
      JSON.parse(@raw)
    rescue JSON::ParserError
      begin
        YAML.safe_load(@raw, permitted_classes: [ Date, Time ])
      rescue Psych::Exception
        raise Invalid, "No se pudo leer el análisis: formato JSON/YAML inválido"
      end
    end

    def normalize_criteria(items, criteria_by_key)
      items.filter_map do |item|
        next unless item.is_a?(Hash)

        criterion = criteria_by_key[item["key"].to_s]
        unless criterion
          errors << "Criterio desconocido ignorado: #{item['key']}"
          next
        end

        points = Integer(item["points"], exception: false)
        if points.nil? || points.negative? || points > criterion.max_points
          errors << "Puntos inválidos en #{criterion.key} (máx. #{criterion.max_points}); se ignoró"
          next
        end

        basis = item["basis"].to_s
        basis = "inferred" unless LeadScore::BASES.include?(basis)
        { "key" => criterion.key, "points" => points, "basis" => basis, "justification" => item["justification"].to_s.strip }
      end
    end
end
