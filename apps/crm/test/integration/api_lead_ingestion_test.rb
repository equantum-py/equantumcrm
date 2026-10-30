require "test_helper"

class ApiLeadIngestionTest < ActionDispatch::IntegrationTest
  setup do
    @client, @token = ApiClient.issue!(name: "prospect-ai-#{SecureRandom.hex(3)}")
  end

  def payload(**overrides)
    {
      source: "freelance_other",
      original_url: "https://www.freelancer.com/projects/demo/sintetico-#{SecureRandom.hex(4)}",
      title: "Tienda online sintética",
      text_excerpt: "Texto sintético: busco tienda online para una marca de prueba.",
      published_at: 2.hours.ago.iso8601,
      published_at_verified: true,
      country_hint: "ES",
      contact_channel: { kind: "platform_message" },
      published_budget_text: "EUR 250-750",
      captured_by: "test",
      evidence: [ { kind: "post_excerpt", captured_at: Time.current.iso8601 } ]
    }.merge(overrides)
  end

  def ingest(body, key: SecureRandom.uuid, token: @token)
    post api_v1_lead_ingestions_path, params: body.to_json,
         headers: { "Authorization" => "Bearer #{token}", "Idempotency-Key" => key, "Content-Type" => "application/json" }
  end

  test "creates an unverified api lead with evidence" do
    assert_difference -> { Lead.count } => 1, -> { LeadEvidence.count } => 1 do
      ingest(payload)
    end
    assert_response :created
    body = response.parsed_body
    lead = Lead.find(body.dig("lead", "id"))
    assert_equal false, body["duplicate"]
    assert_equal "api", lead.created_via
    assert_equal "unverified", lead.verification_status
    assert lead.published_at_verified
    assert_equal "ES", lead.country.iso2
    assert_nil lead.score
    assert_equal @client, AuditLog.where(auditable: lead).last.api_client
  end

  test "stores an attached analysis as pending review without scoring" do
    analysis = { engine_version: "rules-test", services: [ { key: "ecommerce", confidence: 0.8 }, { key: "inventado", confidence: 0.9 } ],
                 criteria: [ { key: "explicit_intent", points: 25, basis: "verified", justification: "dice busco" } ] }
    ingest(payload(analysis: analysis))
    assert_response :created
    lead = Lead.find(response.parsed_body.dig("lead", "id"))
    pending = lead.ai_analyses.pending.sole
    assert_equal [ "ecommerce" ], pending.service_keys
    assert_equal "rules-test", pending.engine_version
    assert_empty lead.lead_scores
  end

  test "warns when the analysis fingerprint differs" do
    ingest(payload(analysis: { fingerprint: "sha256:otra", criteria: [] }))
    lead = Lead.find(response.parsed_body.dig("lead", "id"))
    assert_includes lead.ai_analyses.sole.output["warnings"].join, "no coincide"
  end

  test "same fingerprint with a new key returns the existing lead" do
    body = payload
    ingest(body)
    first_id = response.parsed_body.dig("lead", "id")
    variant = body.merge(original_url: body[:original_url].sub("www.", "") + "?utm_source=x")
    assert_no_difference -> { Lead.count } do
      ingest(variant)
    end
    assert_response :ok
    assert_equal first_id, response.parsed_body.dig("lead", "id")
    assert response.parsed_body["duplicate"]
  end

  test "replays the same key and body" do
    body = payload
    ingest(body, key: "clave-fija-0001")
    assert_response :created
    assert_no_difference -> { Lead.count } do
      ingest(body, key: "clave-fija-0001")
    end
    assert_response :created
    assert_equal "true", response.headers["Idempotent-Replayed"]
  end

  test "rejects the same key with a different body" do
    ingest(payload, key: "clave-fija-0002")
    ingest(payload, key: "clave-fija-0002")
    assert_response :conflict
    assert_equal "idempotency_conflict", response.parsed_body.dig("error", "code")
  end

  test "stores platform competition and deadline" do
    ingest(payload(competition_count: 31, deadline_at: 6.days.from_now.iso8601, listing_closed: false))
    lead = Lead.find(response.parsed_body.dig("lead", "id"))
    assert_equal 31, lead.competition_count
    assert lead.deadline_at.future?
    ingest(payload(competition_count: -1))
    assert_includes response.parsed_body.dig("error", "details").keys, "competition_count"
  end

  test "validation errors are reported per field" do
    ingest(payload(source: "desconocida", text_excerpt: "", original_url: "javascript:alert(1)", country_hint: "ZZ"))
    assert_response :unprocessable_content
    details = response.parsed_body.dig("error", "details")
    assert_equal %w[country_hint original_url source text_excerpt], details.keys.sort
  end

  test "requires an idempotency key" do
    post api_v1_lead_ingestions_path, params: payload.to_json,
         headers: { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
    assert_response :unprocessable_content
  end

  test "rejects malformed json" do
    post api_v1_lead_ingestions_path, params: "{no json",
         headers: { "Authorization" => "Bearer #{@token}", "Idempotency-Key" => SecureRandom.uuid, "Content-Type" => "application/json" }
    assert_response :bad_request
  end

  test "rejects missing, wrong and revoked tokens" do
    ingest(payload, token: "")
    assert_response :unauthorized
    ingest(payload, token: "eqcrm_falso")
    assert_response :unauthorized
    @client.update!(active: false)
    ingest(payload)
    assert_response :unauthorized
  end

  test "rejects a token without the ingest scope" do
    @client.update!(scopes: [])
    ingest(payload)
    assert_response :forbidden
  end

  test "stores only a digest of the token" do
    refute_includes ApiClient.pluck(:token_digest), @token
    assert_equal @client, ApiClient.authenticate(@token)
  end
end
