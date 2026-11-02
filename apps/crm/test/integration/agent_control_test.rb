require "test_helper"

class AgentControlTest < ActionDispatch::IntegrationTest
  test "analysts and managers see agents, limits and pending approvals" do
    lead = create_lead(title: "Tienda Shopify sintética")
    lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    %w[analyst manager admin].each do |role|
      sign_in create_user(role: role)
      get agent_control_path
      assert_response :success
      assert_select "h3", text: "Analista de prospectos"
      assert_select "li", text: /Enviar propuestas/
      assert_select "a", text: "Tienda Shopify sintética"
      sign_out
    end
  end

  test "sales and viewer roles cannot open Agent Control" do
    %w[sales viewer].each do |role|
      sign_in create_user(role: role)
      get agent_control_path
      assert_redirected_to root_path
      sign_out
    end
  end

  test "empty run history explains what each run will record" do
    sign_in create_user(role: "manager")
    get agent_control_path
    assert_select "p", text: /prospectos, duplicados, errores y pendientes de aprobación/
  end
end
