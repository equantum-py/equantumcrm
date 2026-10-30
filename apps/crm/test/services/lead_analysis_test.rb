require "test_helper"

class LeadAnalysisTest < ActiveSupport::TestCase
  ANALYSIS = {
    services: %w[ecommerce inventado],
    country: "PY",
    criteria: [
      { key: "explicit_intent", points: 25, basis: "verified", justification: "Dice busco quien me haga" },
      { key: "budget", points: 9, basis: "verified" },
      { key: "desconocido", points: 3 }
    ],
    recommended_action: "Responder en el hilo",
    draft_message: "Hola, vi tu publicación…"
  }.to_json

  test "import keeps only known services and valid criteria and reports the rest" do
    output = LeadAnalysisImport.new(ANALYSIS).call
    assert_equal %w[ecommerce], output["services"]
    assert_equal %w[explicit_intent], output["criteria"].map { |c| c["key"] }
    assert_equal 2, output["warnings"].size
  end

  test "import accepts yaml and rejects garbage" do
    assert_equal %w[seo], LeadAnalysisImport.new("services: [seo]\ncriteria: []").call["services"]
    assert_raises(LeadAnalysisImport::Invalid) { LeadAnalysisImport.new("{no es json: [").call }
  end

  test "acceptance applies criteria and services, never sends anything" do
    reviewer = create_user
    lead = create_lead
    analysis = lead.ai_analyses.create!(kind: "scoring_proposal", provider: "skill:claude", output: LeadAnalysisImport.new(ANALYSIS).call)

    LeadAnalysisAcceptance.new(analysis, reviewer).call

    lead.reload
    assert_equal "accepted", analysis.reload.status
    assert_equal [ "ecommerce" ], lead.services.map(&:key)
    assert_equal "PY", lead.country.iso2
    assert_equal 25, lead.lead_scores.sum(:points)
    assert_nil lead.score, "score stays empty until all criteria are present"
    assert_equal "ai_accepted", lead.lead_scores.first.set_by
  end
end
