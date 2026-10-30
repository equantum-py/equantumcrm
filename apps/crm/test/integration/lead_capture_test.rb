require "test_helper"

class LeadCaptureTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(role: "sales")
    sign_in @user
    @source = Source.find_by!(key: "facebook_group")
  end

  def capture(url:, analysis: nil)
    post leads_path, params: { lead: { title: "Busca tienda online", original_url: url, source_id: @source.id,
                                       need_summary: "Texto sintético de prueba", analysis: analysis } }
  end

  test "quick capture registers lead with evidence and redirects duplicates to the existing record" do
    assert_difference -> { Lead.count } => 1, -> { LeadEvidence.count } => 1 do
      capture(url: "https://www.facebook.com/groups/9/posts/8/")
    end
    lead = Lead.last
    assert_redirected_to lead_path(lead)
    assert_equal @user, lead.owner

    assert_no_difference -> { Lead.count } do
      capture(url: "https://m.facebook.com/groups/9/posts/8/?mibextid=abc")
    end
    assert_redirected_to lead_path(lead)
  end

  test "pasted analysis stays pending until accepted, then Rails computes the score" do
    criteria = ScoringCriterion.current.map { |c| { key: c.key, points: c.max_points / 2, basis: "inferred", justification: "sintético" } }
    analysis = { services: [ "shopify" ], criteria: criteria, recommended_action: "Responder", draft_message: "Borrador" }.to_json
    capture(url: "https://www.facebook.com/groups/9/posts/10/", analysis: analysis)
    lead = Lead.last
    assert_nil lead.score
    pending = lead.ai_analyses.pending.sole

    patch accept_lead_analysis_path(lead, pending)
    lead.reload
    assert_equal ScoringCriterion.current.sum { |c| c.max_points / 2 }, lead.score
    assert_equal [ "shopify" ], lead.services.map(&:key)
    assert_equal "Borrador", lead.suggested_message
  end

  test "invalid analysis re-renders the form without creating the lead" do
    assert_no_difference -> { Lead.count } do
      capture(url: "https://www.facebook.com/groups/9/posts/11/", analysis: "{roto")
    end
    assert_response :unprocessable_content
  end

  test "manual scoring, verification, qualification and conversion to pipeline" do
    lead = create_lead(owner: @user)
    scores = ScoringCriterion.current.to_h { |c| [ c.key, { points: c.max_points, basis: "verified", justification: "ok" } ] }
    patch lead_score_path(lead), params: { scores: scores }
    assert_equal 100, lead.reload.score
    assert_equal "very_high", lead.score_band

    patch qualify_lead_path(lead)
    assert_equal "new", lead.reload.status, "cannot qualify before verifying the source"

    patch verify_lead_path(lead)
    patch qualify_lead_path(lead)
    assert_equal "qualified", lead.reload.status

    assert_difference -> { Opportunity.count } => 1, -> { Company.count } => 1 do
      post convert_lead_path(lead), params: { company_name: "Comercial Sintética" }
    end
    assert_equal "converted", lead.reload.status
    assert_equal "Pendiente de contacto", lead.opportunity.pipeline_stage.name
  end

  test "score above criterion maximum is rejected" do
    lead = create_lead
    patch lead_score_path(lead), params: { scores: { budget: { points: 50, basis: "verified" } } }
    assert_response :unprocessable_content
    assert_equal 0, lead.lead_scores.count
  end
end
