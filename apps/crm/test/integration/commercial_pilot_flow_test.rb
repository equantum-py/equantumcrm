require "test_helper"

# Commercial pilot, end to end, with synthetic data only:
# capture → verification → analysis → qualification → opportunity → activity → proposal.
# Each step checks who may do it and that it leaves an audit entry.
class CommercialPilotFlowTest < ActionDispatch::IntegrationTest
  setup do
    _client, @token = ApiClient.issue!(name: "piloto-#{SecureRandom.hex(3)}")
    @sales = create_user(role: "sales")
    @viewer = create_user(role: "viewer")
  end

  test "a synthetic opportunity goes from capture to proposal with permissions and audit at every step" do
    # 1. Capture through the API: unverified, unscored, analysis pending review.
    criteria = ScoringCriterion.current.map { |c| { key: c.key, points: c.max_points, basis: "verified", justification: "sintético" } }
    body = { source: "freelance_other", original_url: "https://www.freelancer.com/projects/demo/piloto-#{SecureRandom.hex(4)}",
             title: "[DEMO] Piloto: tienda Shopify sintética", text_excerpt: "Texto sintético: busco tienda Shopify.",
             published_at: 1.hour.ago.iso8601, published_at_verified: true, country_hint: "ES",
             contact_channel: { kind: "platform_message" }, captured_by: "piloto",
             evidence: [ { kind: "post_excerpt", captured_at: Time.current.iso8601 } ],
             analysis: { engine_version: "piloto", services: [ { key: "shopify", confidence: 0.9 } ], criteria: criteria } }
    post api_v1_lead_ingestions_path, params: body.to_json,
         headers: { "Authorization" => "Bearer #{@token}", "Idempotency-Key" => SecureRandom.uuid, "Content-Type" => "application/json" }
    assert_response :created
    lead = Lead.find(response.parsed_body.dig("lead", "id"))
    assert_equal [ "unverified", nil ], [ lead.verification_status, lead.score ]
    analysis = lead.ai_analyses.pending.sole
    assert AuditLog.exists?(action: "create", auditable: lead)

    # A viewer can read but not act.
    sign_in @viewer
    get lead_path(lead)
    assert_response :success
    patch verify_lead_path(lead)
    assert_equal "unverified", lead.reload.verification_status
    patch accept_lead_analysis_path(lead, analysis)
    assert_equal "pending_review", analysis.reload.status
    delete session_path

    sign_in @sales
    # 2. Verification.
    patch verify_lead_path(lead)
    assert_equal "verified", lead.reload.verification_status
    assert audited?(lead, "verification_status")

    # 3. Analysis: accepted by a person; Rails computes the score.
    patch accept_lead_analysis_path(lead, analysis)
    assert_equal "accepted", analysis.reload.status
    assert_equal 100, lead.reload.score
    assert audited?(lead, "score")

    # 4. Qualification.
    patch qualify_lead_path(lead)
    assert_equal "qualified", lead.reload.status
    assert audited?(lead, "status")

    # 5. Opportunity.
    assert_difference -> { Opportunity.count } => 1 do
      post convert_lead_path(lead)
    end
    opportunity = lead.reload.opportunity
    assert AuditLog.exists?(action: "create", auditable: opportunity)

    # 6. Activity.
    assert_difference -> { Activity.count } => 1 do
      post activities_path, params: { activity: { kind: "task", title: "Preparar propuesta sintética",
                                                  subject_type: "Opportunity", subject_id: opportunity.id } }
    end

    # 7. Proposal stage. The CRM never sends the proposal itself.
    proposal = PipelineStage.find_by!(name: "Propuesta enviada")
    patch move_opportunity_path(opportunity), params: { pipeline_stage_id: proposal.id }
    assert_equal proposal, opportunity.reload.pipeline_stage
    assert audited?(opportunity, "pipeline_stage_id")

    # Every audited step names who did it.
    assert AuditLog.where(auditable: [ lead, opportunity ]).where.not(action: "create").all? { |log| log.actor.present? }
  end

  private
    def audited?(record, attribute)
      AuditLog.where(auditable: record, action: "update").any? { |log| log.changeset.key?(attribute) }
    end
end
