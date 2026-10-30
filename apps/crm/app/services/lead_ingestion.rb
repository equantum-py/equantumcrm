# Creates a lead from an API payload (Prospect AI or a Skill runner). It
# validates the payload, detects duplicates by fingerprint and stores an
# optional analysis as pending review. It never scores or qualifies a lead:
# that stays a human decision inside Rails.
class LeadIngestion
  Result = Data.define(:status, :body, :lead)

  CONTACT_KINDS = %w[public_comment platform_message email phone website none].freeze
  MAX_EVIDENCE = 5

  def initialize(payload, api_client:)
    @payload = payload.is_a?(Hash) ? payload.deep_stringify_keys : {}
    @api_client = api_client
    @errors = Hash.new { |hash, key| hash[key] = [] }
  end

  def call
    attributes = validated_attributes
    return failure if @errors.any?

    lead = Lead.new(attributes)
    lead.validate
    if (existing = Lead.find_by(fingerprint: lead.fingerprint))
      return Result.new(status: 200, body: body_for(existing, duplicate: true), lead: existing)
    end

    analysis = nil
    Lead.transaction do
      lead.save!
      add_evidence(lead)
      analysis = add_analysis(lead)
      lead.refresh_priority!
    end
    Result.new(status: 201, body: body_for(lead, duplicate: false, analysis: analysis), lead: lead)
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.each { |error| @errors[error.attribute.to_s] << error.message }
    failure
  rescue ActiveRecord::RecordNotUnique
    existing = Lead.find_by(fingerprint: lead&.fingerprint)
    existing ? Result.new(status: 200, body: body_for(existing, duplicate: true), lead: existing) : raise
  end

  private
    attr_reader :payload

    def validated_attributes
      source = Source.find_by(key: payload["source"].to_s)
      @errors["source"] << "no es una fuente registrada" unless source

      text = payload["text_excerpt"].to_s.strip
      @errors["text_excerpt"] << "es obligatorio" if text.empty?
      @errors["text_excerpt"] << "supera 2000 caracteres" if text.length > 2000

      url = payload["original_url"].to_s.strip.presence
      @errors["original_url"] << "debe ser una URL http(s) válida" if url && !UrlCanonicalizer.http_url?(url)

      country = nil
      if (hint = payload["country_hint"].to_s.upcase.presence)
        country = Country.find_by(iso2: hint)
        @errors["country_hint"] << "no es un país registrado" unless country
      end

      contact_kind = payload.dig("contact_channel", "kind").to_s.presence
      @errors["contact_channel.kind"] << "no es válido" if contact_kind && CONTACT_KINDS.exclude?(contact_kind)

      competition = payload["competition_count"]
      if competition && !(competition.is_a?(Integer) && competition >= 0)
        @errors["competition_count"] << "debe ser un entero mayor o igual a 0"
      end

      check_length("title", 200)
      check_length("external_id", 120)
      check_length("author_display_name", 120)
      check_length("published_budget_text", 200)
      @errors["evidence"] << "admite como máximo #{MAX_EVIDENCE} elementos" if evidence_items.size > MAX_EVIDENCE
      @errors["analysis"] << "debe ser un objeto" if payload.key?("analysis") && !payload["analysis"].nil? && !payload["analysis"].is_a?(Hash)

      {
        source: source,
        country: country,
        title: (payload["title"].to_s.strip.presence || text.truncate(120, separator: " ")),
        need_summary: text,
        original_url: url,
        external_id: payload["external_id"].to_s.strip.presence,
        published_at: parse_time("published_at"),
        published_at_verified: ActiveModel::Type::Boolean.new.cast(payload["published_at_verified"]) || false,
        author_display_name: payload["author_display_name"].to_s.strip.presence,
        contact_channel_kind: contact_kind,
        published_budget_text: payload["published_budget_text"].to_s.strip.presence,
        competition_count: competition.is_a?(Integer) ? competition : nil,
        deadline_at: parse_time("deadline_at"),
        listing_closed: payload["listing_closed"] == true,
        created_via: "api",
        status: "new",
        verification_status: "unverified"
      }
    end

    def check_length(field, max)
      @errors[field] << "supera #{max} caracteres" if payload[field].to_s.length > max
    end

    def parse_time(field)
      return if payload[field].blank?

      Time.iso8601(payload[field].to_s)
    rescue ArgumentError
      @errors[field] << "debe ser una fecha ISO 8601"
      nil
    end

    def evidence_items
      Array(payload["evidence"]).select { |item| item.is_a?(Hash) }
    end

    def add_evidence(lead)
      items = evidence_items.presence || [ { "kind" => "post_excerpt" } ]
      items.each do |item|
        captured_at = Time.iso8601(item["captured_at"].to_s) rescue Time.current
        kind = LeadEvidence::KINDS.include?(item["kind"]) ? item["kind"] : "post_excerpt"
        lead.lead_evidences.create!(kind: kind, url: lead.original_url, excerpt: item["excerpt"].presence || lead.need_summary,
                                    captured_at: captured_at)
      end
    end

    def add_analysis(lead)
      raw = payload["analysis"]
      return unless raw.is_a?(Hash)

      output = LeadAnalysisImport.new(raw.to_json).call
      if raw["fingerprint"].present? && raw["fingerprint"] != lead.fingerprint
        output["warnings"] << "La huella calculada por Prospect AI no coincide con la del CRM"
      end
      lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:#{@api_client.name}",
                               engine_version: raw["engine_version"].to_s.presence || "desconocida", output: output)
    end

    def body_for(lead, duplicate:, analysis: nil)
      {
        "lead" => { "id" => lead.id, "fingerprint" => lead.fingerprint, "status" => lead.status, "path" => "/leads/#{lead.id}" },
        "duplicate" => duplicate,
        "analysis_id" => analysis&.id
      }
    end

    def failure
      Result.new(status: 422, body: { "error" => { "code" => "validation_failed", "message" => "La solicitud tiene errores", "details" => @errors.to_h } }, lead: nil)
    end
end
