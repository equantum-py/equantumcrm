require "test_helper"

class CommercialPriorityUiTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: "admin")
    sign_in @admin
  end

  test "admin registers a threshold with currency-aware amounts" do
    post admin_commercial_thresholds_path, params: { commercial_threshold: { min_viable_amount: "1.500.000", high_value_amount: "9000000", currency: "PYG" } }
    assert_redirected_to admin_commercial_thresholds_path
    threshold = CommercialThreshold.find_by!(currency: "PYG")
    assert_equal 1_500_000, threshold.min_viable_cents
    assert_equal @admin, threshold.approved_by
    get admin_commercial_thresholds_path
    assert_select "td", text: "Pendiente de aprobación", count: 4
  end

  test "sales users cannot manage thresholds" do
    delete session_path
    sign_in create_user(role: "sales")
    post admin_commercial_thresholds_path, params: { commercial_threshold: { currency: "USD", min_viable_amount: "1", high_value_amount: "2" } }
    assert_nil CommercialThreshold.find_by(currency: "USD")
  end

  test "lead form stores commercial data and the page shows priority once v2 is active" do
    lead = create_lead
    patch lead_path(lead), params: { lead: { budget_max_amount: "5000", budget_min_amount: "3000", budget_currency: "USD",
                                             competition_count: "156", service_ids: [ Service.find_by!(key: "app_web").id ] } }
    lead.reload
    assert_equal [ 300_000, 500_000, 156 ], [ lead.budget_min_cents, lead.budget_max_cents, lead.competition_count ]
    assert_nil lead.commercial_priority

    RubricMigration.new(from: 1, to: 2).activate!(approved_by: @admin)
    patch lead_path(lead), params: { lead: { urgency: "medium" } }
    get lead_path(lead)
    assert_select "h2", text: "Prioridad comercial"
    assert_match "Sin datos (fuera del cálculo)", response.body
  end

  test "accepting an analysis fills the budget when the lead has none" do
    lead = create_lead
    output = LeadAnalysisImport.new({ services: [ { key: "seo" } ], budget: { currency: "EUR", min: "250", max: "750" }, criteria: [] }.to_json).call
    analysis = lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:test", output: output)
    patch accept_lead_analysis_path(lead, analysis)
    lead.reload
    assert_equal [ "EUR", 25_000, 75_000 ], [ lead.budget_currency, lead.budget_min_cents, lead.budget_max_cents ]
  end
end
