require "test_helper"

class PipelineTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(role: "sales")
    sign_in @user
  end

  test "kanban and table render real opportunities" do
    opportunity = create_opportunity(owner: @user, name: "Migración a Shopify")
    get opportunities_path
    assert_select "article[data-id='#{opportunity.id}']", text: /Migración a Shopify/
    get opportunities_path(view: "table")
    assert_select "td", text: /Migración a Shopify/
  end

  test "creating an opportunity from the form without choosing a currency works (regression B2)" do
    company = create_company
    assert_difference -> { Opportunity.count } => 1 do
      post opportunities_path, params: { opportunity: { name: "Sin moneda elegida", company_id: company.id,
        pipeline_stage_id: PipelineStage.ordered.first.id, owner_id: @user.id, currency: "", estimated_value: "" } }
    end
    assert_nil Opportunity.find_by!(name: "Sin moneda elegida").currency
  end

  test "moving to lost requires a reason and logs an activity" do
    opportunity = create_opportunity(owner: @user)
    lost = PipelineStage.find_by!(kind: "lost")

    patch move_opportunity_path(opportunity), params: { pipeline_stage_id: lost.id }, as: :json
    assert_response :unprocessable_content

    assert_difference -> { opportunity.activities.count } => 1 do
      patch move_opportunity_path(opportunity), params: { pipeline_stage_id: lost.id, lost_reason: "Sin presupuesto" }, as: :json
    end
    assert_response :success
    assert opportunity.reload.lost_at
  end

  test "opportunity shows pending price when no approved rate exists" do
    opportunity = create_opportunity(owner: @user, services: [ Service.find_by!(key: "seo") ])
    get opportunity_path(opportunity)
    assert_select "p", text: "Precio pendiente de aprobación"
  end

  test "activities can be created and completed from a record" do
    opportunity = create_opportunity(owner: @user)
    post activities_path, params: { activity: { subject_type: "Opportunity", subject_id: opportunity.id, kind: "follow_up", title: "Enviar ejemplos", due_at: 1.hour.ago } }
    activity = opportunity.activities.sole
    get activities_path
    assert_select "section", text: /Vencidas/
    patch complete_activity_path(activity)
    assert activity.reload.completed?
  end

  test "activity subject type is restricted" do
    post activities_path, params: { activity: { subject_type: "User", subject_id: @user.id, kind: "note", title: "x" } }
    assert_redirected_to root_path
    assert_equal 0, Activity.count
  end
end
