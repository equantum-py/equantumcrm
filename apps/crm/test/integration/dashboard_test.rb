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

class DashboardCaptureTest < ActionDispatch::IntegrationTest
  test "capture queues count open work and ignore closed leads" do
    user = create_user
    create_lead(title: "Cierra mañana", deadline_at: 1.day.from_now)
    create_lead(title: "Cierra en un mes", deadline_at: 30.days.from_now)
    create_lead(title: "Publicación cerrada", deadline_at: 2.days.from_now, listing_closed: true)
    analyzed = create_lead(title: "Con análisis pendiente")
    analyzed.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    create_lead(title: "Descartado", status: "discarded", discard_reason: "fuera de foco", deadline_at: 1.day.from_now)

    metrics = DashboardMetrics.new
    assert_equal 4, metrics.to_verify
    assert_equal 1, metrics.pending_ai_reviews
    assert_equal [ "Cierra mañana" ], metrics.closing_soon.map(&:title)
    assert_equal({ "manual" => 5 }, metrics.leads_by_channel)

    sign_in user
    get root_path
    assert_response :success
    assert_select "h1", text: "Captación comercial"
    assert_select "a", text: "Cierra mañana"
  end

  test "unverified filter lists only open unverified leads" do
    sign_in create_user
    create_lead(title: "Abierto sin verificar")
    create_lead(title: "Descartado sin verificar", status: "discarded", discard_reason: "sin presupuesto")
    get leads_path(verification: "unverified")
    assert_select "a", text: "Abierto sin verificar"
    assert_select "a", text: "Descartado sin verificar", count: 0
  end

  test "high priority is split into confirmed and estimated" do
    confirmed = create_lead(title: "Alta confirmada", commercial_priority: "high", verification_status: "verified", score: 70, score_band: "high")
    create_lead(title: "Alta sin verificar", commercial_priority: "high", score: 70, score_band: "high")
    pending = create_lead(title: "Alta con IA pendiente", commercial_priority: "high", verification_status: "verified", score: 70, score_band: "high")
    pending.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    create_lead(title: "Alta duplicada A", commercial_priority: "high", verification_status: "verified", score: 70, score_band: "high", author_display_name: "Ana")
    create_lead(title: "Alta duplicada B", author_display_name: "Ana")

    metrics = DashboardMetrics.new
    assert_equal 4, metrics.high_priority_without_opportunity
    assert_equal 1, metrics.high_priority_confirmed
    assert_equal 3, metrics.high_priority_estimated
    assert_equal [ confirmed ], Lead.priority_confirmed.where(commercial_priority: "high").to_a

    sign_in create_user
    get root_path
    assert_select "dt", text: "Prioridad alta confirmada"
    assert_select "p", text: /3 con prioridad alta estimada/
    get leads_path(priority: "high", priority_status: "confirmed")
    assert_select "a", text: "Alta confirmada"
    assert_select "a", text: "Alta sin verificar", count: 0
  end

  test "test and demo leads are never counted" do
    create_lead(title: "Real")
    create_lead(title: "[DEMO] Tienda de ejemplo", commercial_priority: "high", verification_status: "verified", score: 80, score_band: "very_high")
    create_lead(title: "Marcado como prueba", synthetic: true, deadline_at: 1.day.from_now)
    old = create_lead(title: "Anterior a la columna")
    old.update_columns(title: "[SINTÉTICO] Anterior a la columna", synthetic: false)

    metrics = DashboardMetrics.new
    assert_equal 1, metrics.leads_detected
    assert_equal 1, metrics.to_verify
    assert_equal 0, metrics.high_priority_without_opportunity
    assert_equal 0, metrics.closing_soon_count
    assert Lead.find_by!(title: "[DEMO] Tienda de ejemplo").synthetic
  end

  test "queues keep the commercial filters" do
    py = Country.find_by!(iso2: "PY")
    create_lead(title: "Paraguay", country: py)
    create_lead(title: "Otro país")
    assert_equal 1, DashboardMetrics.new(country_id: py.id).to_verify

    sign_in create_user
    get root_path(country_id: py.id)
    assert_select "a[href=?]", leads_path(country_id: py.id, verification: "unverified")
  end
end
