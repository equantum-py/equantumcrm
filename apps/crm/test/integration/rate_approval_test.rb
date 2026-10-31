require "test_helper"

# Synthetic amounts; no real price is loaded.
class RateApprovalTest < ActionDispatch::IntegrationTest
  setup do
    @service = Service.find_by!(key: "seo")
    @params = { service_rate: { service_id: @service.id, currency: "PYG", unit: "month", min_amount: "1", max_amount: "2", valid_from: Date.current } }
  end

  test "a new rate waits for approval and editing an approved rate sends it back" do
    manager = create_user(role: "manager")
    sign_in manager
    post admin_service_rates_path, params: @params
    rate = ServiceRate.order(:id).last
    assert_equal [ "pending", manager ], [ rate.status, rate.created_by ]
    assert_nil ServiceRate.current_for(@service, nil)

    patch approve_admin_service_rate_path(rate)
    rate.reload
    assert_equal [ "approved", manager ], [ rate.status, rate.approved_by ]
    assert_equal rate, ServiceRate.current_for(@service, nil)

    patch admin_service_rate_path(rate), params: { service_rate: { max_amount: "3" } }
    rate.reload
    assert_equal "pending", rate.status
    assert_nil rate.approved_by
    assert_nil ServiceRate.current_for(@service, nil)
  end

  test "analysts cannot approve" do
    rate = ServiceRate.create!(service: @service, currency: "PYG", unit: "month", min_cents: 1, max_cents: 2, valid_from: Date.current)
    sign_in create_user(role: "analyst")
    patch approve_admin_service_rate_path(rate)
    assert_equal "pending", rate.reload.status
  end

  test "approved rows cannot exist without an approver" do
    rate = ServiceRate.new(service: @service, currency: "PYG", unit: "month", min_cents: 1, max_cents: 2, valid_from: Date.current, status: "approved")
    assert_not rate.valid?
  end
end
