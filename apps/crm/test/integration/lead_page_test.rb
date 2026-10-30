require "test_helper"

# Commercial layout of the lead page. Synthetic data only.
class LeadPageTest < ActionDispatch::IntegrationTest
  setup do
    @lead = create_lead(title: "Tienda sintética", original_url: "https://example.com/demo/1", recommended_action: "Responder en el hilo",
                        budget_currency: "EUR", budget_min_cents: 25_000, budget_max_cents: 75_000)
    @lead.services = Service.where(key: "shopify")
  end

  test "summary shows the key facts and the next step first" do
    sign_in create_user(role: "sales")
    get lead_path(@lead)
    assert_select "h1#lead-title", "Tienda sintética"
    assert_select "dl dt", text: "Presupuesto publicado"
    assert_select "dd", text: "EUR 250,00 – EUR 750,00"
    assert_select "dt", text: "Intención"
    assert_select "dt", text: "Prioridad comercial"
    assert_select "p", text: "Responder en el hilo"
    assert_select "nav[aria-label='Acciones comerciales']" do
      assert_select "a[href='https://example.com/demo/1'][rel~=noopener]", text: "Ver fuente ↗"
      assert_select "button.bg-indigo-600", text: "Verificar"
      assert_select "button[disabled]", text: "Calificar"
      assert_select "a[href='#actividades']", text: "Crear actividad"
      assert_select "a[href='#contacto']", text: "Preparar contacto"
    end
    assert_match "Para calificar falta verificar la fuente y completar la puntuación", response.body
  end

  test "qualified and scored leads put conversion first" do
    @lead.update!(verification_status: "verified")
    score_all!(@lead)
    @lead.update!(status: "qualified")
    sign_in create_user(role: "sales")
    get lead_path(@lead)
    assert_select "nav[aria-label='Acciones comerciales'] button.bg-indigo-600", text: "Convertir en oportunidad"
    assert_select "nav button", text: "Verificar", count: 0
  end

  test "analysis separates proposed, approved and final score, with details folded" do
    output = LeadAnalysisImport.new({ services: [ { key: "shopify" } ], country: "ES",
                                      criteria: [ { key: "explicit_intent", points: 25, basis: "verified", justification: "Dice busco" } ] }.to_json).call
    @lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:test", output: output)
    sign_in create_user(role: "sales")
    get lead_path(@lead)
    assert_select "p", text: "1 · Propuesto"
    assert_select "p", text: "2 · Aprobado"
    assert_select "p", text: "3 · Puntuación definitiva"
    assert_match "Encaja con Shopify / Shopify Plus. Hay intención de contratar: dice busco. País probable: España.", response.body
    assert_select "details summary", text: "Ver criterios propuestos y advertencias"
    assert_select "details summary", text: "Ver puntuación definitiva por criterio"
  end

  test "viewers see the summary without commercial actions" do
    sign_in create_user(role: "viewer")
    get lead_path(@lead)
    assert_response :success
    assert_select "nav[aria-label='Acciones comerciales'] button", count: 0
    assert_select "summary", text: "Descartar prospecto", count: 0
  end
end
