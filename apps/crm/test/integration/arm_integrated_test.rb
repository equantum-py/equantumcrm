require "test_helper"

class ArmIntegratedTest < ActionDispatch::IntegrationTest
  test "premium presentation reads canonical real-data metrics" do
    user = create_user
    real = create_lead(title: "Real verificado", verification_status: "verified", commercial_priority: "high", score: 70, score_band: "high")
    synthetic = create_lead(title: "Prueba sin prefijo", synthetic: true, verification_status: "verified", commercial_priority: "high", score: 70, score_band: "high")
    create_lead(title: "[DEMO] Registro heredado", verification_status: "verified")
    create_opportunity(owner: user, lead: synthetic, name: "Oportunidad de prueba oculta")
    visible = create_opportunity(owner: user, lead: real, name: "Oportunidad real visible")
    metrics = DashboardMetrics.new
    assert_equal 1, metrics.leads_verified
    assert_equal 1, metrics.active_opportunities
    assert_equal 1, metrics.capture_series.sum(&:last)
    assert_equal({ "high" => 1 }, metrics.commercial_priorities)
    assert_equal [ visible.id ], metrics.opportunities_preview.map(&:id)
    assert_equal [ real.id ], metrics.opportunity_confirmed_priority_ids
    sign_in user
    get root_path
    assert_response :success
    assert_select "td a", text: visible.name
    assert_select "td a", text: "Oportunidad de prueba oculta", count: 0
  end

  test "queue links preserve commercial filters and split priority approval" do
    country = Country.find_by!(iso2: "PY")
    confirmed = create_lead(country: country, verification_status: "verified", commercial_priority: "high", score: 70, score_band: "high")
    create_lead(country: country, commercial_priority: "high", detected_at: 90.days.ago)
    sign_in create_user
    get root_path(country_id: country.id)
    assert_select "a[href=?]", leads_path(country_id: country.id, priority: "high", priority_status: "confirmed")
    assert_select "a[href=?]", leads_path(country_id: country.id, priority: "high", priority_status: "estimated")
    assert_select ".arm-queue-metrics .arm-metric:nth-child(3) dd a", text: "1"
    assert_select ".arm-queue-metrics .arm-metric:nth-child(4) dd a", text: "1"
    get leads_path(country_id: country.id, priority: "high", priority_status: "confirmed")
    assert_response :success
    assert_select "tr[data-records-target='row']", count: 1
    assert_select "a", text: confirmed.title
    assert_select "option[selected][value='confirmed']"
  end

  test "premium Agent Control preserves role authorization and does not change agents" do
    before = Agent.ordered.pluck(:id, :enabled, :execution_mode, :schedule)
    %w[manager analyst admin].each do |role|
      sign_in create_user(role: role)
      get root_path
      assert_select "#primary-navigation a[href=?]", agent_control_path
      get agent_control_path
      assert_response :success
      assert_select ".arm-agent-control"
      assert_select "dt", text: /Habilitados/
      assert_select "form[action*='agent']", count: 0
      sign_out
    end
    %w[sales viewer].each do |role|
      sign_in create_user(role: role)
      get root_path
      assert_select "a[href=?]", agent_control_path, count: 0
      get agent_control_path
      assert_redirected_to root_path
      sign_out
    end
    assert_equal before, Agent.ordered.pluck(:id, :enabled, :execution_mode, :schedule)
  end
end
