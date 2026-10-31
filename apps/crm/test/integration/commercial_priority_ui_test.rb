require "test_helper"

class CommercialPriorityUiTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: "admin")
    sign_in @admin
  end

  test "admin edits a threshold with currency-aware amounts and a stated basis" do
    threshold = CommercialThreshold.find_by!(currency: "PYG")
    patch admin_commercial_threshold_path(threshold), params: { commercial_threshold: { medium_from_amount: "4.500.000", high_from_amount: "15000000", approval_reference: "Prueba" } }
    assert_redirected_to admin_commercial_thresholds_path
    assert_equal 4_500_000, threshold.reload.medium_from_cents
    assert_equal @admin, threshold.approved_by
    get admin_commercial_thresholds_path
    assert_match "No son precios", response.body
  end

  test "sales users cannot manage thresholds" do
    delete session_path
    sign_in create_user(role: "sales")
    threshold = CommercialThreshold.find_by!(currency: "USD")
    patch admin_commercial_threshold_path(threshold), params: { commercial_threshold: { medium_from_amount: "1" } }
    assert_equal 50_000, threshold.reload.medium_from_cents
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
    # Unverified and unscored, so it is shown as an estimate.
    assert_select "h2", text: "Prioridad estimada — pendiente de verificación"
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
