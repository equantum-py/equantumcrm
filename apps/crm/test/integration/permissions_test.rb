require "test_helper"

class PermissionsTest < ActionDispatch::IntegrationTest
  test "viewer can read but not create leads" do
    sign_in create_user(role: "viewer")
    get leads_path
    assert_response :success
    get new_lead_path
    assert_redirected_to root_path
    assert_no_difference -> { Lead.count } do
      post leads_path, params: { lead: { title: "x", source_id: Source.first.id } }
    end
  end

  test "sales cannot open administration" do
    sign_in create_user(role: "sales")
    get admin_users_path
    assert_response :redirect
    get admin_audit_logs_path
    assert_response :redirect
    assert_no_difference -> { ServiceRate.count } do
      post admin_service_rates_path, params: { service_rate: { service_id: Service.first.id, currency: "PYG", unit: "project", min_amount: "1", max_amount: "2", valid_from: Date.current } }
    end
  end

  test "sales cannot move another owner's opportunity but a manager can" do
    other = create_user(role: "sales")
    opportunity = create_opportunity(owner: other)
    target = PipelineStage.find_by!(name: "Contactado")

    sign_in create_user(role: "sales")
    patch move_opportunity_path(opportunity), params: { pipeline_stage_id: target.id }, as: :json
    assert_response :forbidden
    assert_not_equal target, opportunity.reload.pipeline_stage

    sign_in create_user(role: "manager")
    patch move_opportunity_path(opportunity), params: { pipeline_stage_id: target.id }, as: :json
    assert_response :success
    assert_equal target, opportunity.reload.pipeline_stage
  end

  test "admin manages users and cannot deactivate themselves" do
    admin = create_user(role: "admin")
    sign_in admin
    post admin_users_path, params: { user: { name: "Nueva", email_address: "nueva@test.equantum.local", password: "una-clave-larga-123", role_id: Role.find_by!(key: "sales").id, active: "1" } }
    assert_redirected_to admin_users_path
    assert User.exists?(email_address: "nueva@test.equantum.local")

    patch admin_user_path(admin), params: { user: { active: "0" } }
    assert admin.reload.active?
  end
end
