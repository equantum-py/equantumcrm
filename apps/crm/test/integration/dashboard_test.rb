require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "empty database shows zeros, never sample figures" do
    sign_in create_user
    get root_path
    assert_response :success
    assert_select "dd", text: "0", minimum: 5
    assert_select "p", text: /Sin oportunidades abiertas con valor estimado/
  end

  test "counts reflect real records and filters" do
    user = create_user
    paraguay = Country.find_by!(iso2: "PY")
    create_lead(country: paraguay)
    create_lead(country: Country.find_by!(iso2: "ES"))
    create_opportunity(owner: user, currency: "PYG", estimated_value: "1000000")
    sign_in user

    metrics = DashboardMetrics.new
    assert_equal 2, metrics.leads_detected
    assert_equal 1, DashboardMetrics.new(country_id: paraguay.id).leads_detected
    assert_equal [ "PYG 1.000.000" ], metrics.pipeline_value_by_currency.map(&:to_s)

    get root_path(country_id: paraguay.id)
    assert_response :success
  end

  test "rates page lists every service as pending when nothing is approved" do
    sign_in create_user(role: "manager")
    get admin_service_rates_path
    assert_select "td", text: "Precio pendiente de aprobación", count: Service.active.count
  end

  test "global search finds leads and companies" do
    user = create_user
    create_lead(title: "Necesita SEO técnico")
    create_company(trade_name: "Ferretería Sintética")
    sign_in user
    get search_path(q: "sint")
    assert_select "a", text: "Ferretería Sintética"
  end
end
