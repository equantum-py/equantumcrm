require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "every page requires sign in" do
    [ root_path, leads_path, opportunities_path, companies_path, activities_path, admin_service_rates_path ].each do |path|
      get path
      assert_redirected_to new_session_path, "#{path} should require authentication"
    end
  end

  test "valid credentials sign in and are audited" do
    user = create_user
    sign_in user
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    assert AuditLog.exists?(action: "sign_in", auditable: user)
  end

  test "wrong password and inactive users are rejected" do
    user = create_user
    post session_path, params: { email_address: user.email_address, password: "incorrecta" }
    assert_redirected_to new_session_path

    user.update!(active: false)
    sign_in user
    assert_redirected_to new_session_path
  end

  test "deactivated user loses existing sessions" do
    user = create_user
    sign_in user
    user.update!(active: false)
    get root_path
    assert_redirected_to new_session_path
  end

  test "sign out ends the session" do
    sign_in create_user
    delete session_path
    get root_path
    assert_redirected_to new_session_path
  end
end
