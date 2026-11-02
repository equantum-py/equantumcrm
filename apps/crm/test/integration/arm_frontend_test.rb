require "test_helper"

class ArmFrontendTest < ActionDispatch::IntegrationTest
  test "ARM shell preserves real empty dashboard and accessible navigation" do
    sign_in create_user
    get root_path
    assert_response :success
    assert_select "title", text: /eQuantum ARM/
    assert_select "h1", text: "Centro de operaciones comerciales"
    assert_select ".arm-period-metrics .arm-metric", count: 6
    assert_select ".arm-period-metrics dd", text: "0", count: 6
    assert_select "a[href='#main-content']", text: "Saltar al contenido"
    assert_select "button[aria-controls='primary-navigation'][aria-expanded='false']"
    assert_select "a", text: "Sales Agent", count: 0
  end

  test "verification and commercial priority cards respect lead date and country filters" do
    user = create_user
    country = Country.find_by!(iso2: "PY")
    create_lead(country: country, verification_status: "verified", commercial_priority: "high")
    create_lead(country: country, detected_at: 60.days.ago, verification_status: "verified", commercial_priority: "high")
    create_lead(country: Country.find_by!(iso2: "ES"), verification_status: "verified", commercial_priority: "high")
    sign_in user
    get root_path(country_id: country.id)
    assert_response :success
    assert_select ".arm-period-metrics .arm-metric:nth-child(2) dd", text: "1"
    assert_select ".arm-period-metrics .arm-metric:nth-child(4) dd", text: "0"
    assert_select ".arm-queue-metrics .arm-metric:nth-child(4) dd a", text: "2"
  end

  test "capture visualization bounds long date ranges" do
    sign_in create_user
    create_lead
    get root_path(from: 10.years.ago.to_date.iso8601)
    assert_response :success
    assert_select ".arm-capture-day", maximum: 60, minimum: 1
  end

  test "capture chart groups late detections by the application timezone" do
    sign_in create_user
    day = Date.current - 1.day
    create_lead(detected_at: Time.zone.local(day.year, day.month, day.day, 23, 30))
    get root_path(from: day.iso8601, to: day.iso8601)
    assert_response :success
    assert_select ".arm-capture-day", count: 1
    assert_select ".arm-capture-day[aria-label$=': 1 prospectos']", count: 1
  end

  test "prospect listing distinguishes explicitly marked demo and keeps server filters" do
    sign_in create_user
    create_lead(title: "[DEMO] Tienda de prueba")
    create_lead(title: "Solicitud comercial")
    create_lead(title: "Prueba sin prefijo", synthetic: true)
    get leads_path
    assert_response :success
    assert_select ".arm-demo", count: 2
    assert_select "select[name='country_id']"
    assert_select "select[name='verification']"
    assert_select "select[name='priority_status']"
    assert_select "tr[data-records-target='row']", count: 3
  end

  test "open opportunity focus excludes closed stages" do
    user = create_user
    create_opportunity(owner: user, name: "Abierta visible")
    create_opportunity(owner: user, stage: PipelineStage.find_by!(kind: "won"), name: "Ganada fuera de foco")
    sign_in user
    get root_path
    assert_response :success
    assert_select "td a", text: "Abierta visible"
    assert_select "td a", text: "Ganada fuera de foco", count: 0
  end
end
