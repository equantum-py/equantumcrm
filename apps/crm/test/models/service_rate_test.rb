require "test_helper"

class ServiceRateTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(role: "admin")
    @service = Service.find_by!(key: "shopify")
    @paraguay = Country.find_by!(iso2: "PY")
  end

  test "no rate means pending price" do
    assert_nil ServiceRate.current_for(@service, @paraguay)
  end

  test "country rate wins over general rate and expired rates are ignored" do
    general = ServiceRate.create!(service: @service, currency: "USD", unit: "project", min_cents: 1, max_cents: 2, valid_from: 1.month.ago, status: "approved", approved_by: @admin, approved_at: Time.current)
    assert_equal general, ServiceRate.current_for(@service, @paraguay)

    local = ServiceRate.create!(service: @service, country: @paraguay, currency: "PYG", unit: "project", min_cents: 1, max_cents: 2, valid_from: 1.month.ago, status: "approved", approved_by: @admin, approved_at: Time.current)
    assert_equal local, ServiceRate.current_for(@service, @paraguay)

    local.update!(valid_until: 1.day.ago)
    assert_equal general, ServiceRate.current_for(@service, @paraguay)
  end

  test "max must not be below min" do
    rate = ServiceRate.new(service: @service, currency: "EUR", unit: "hour", min_cents: 10, max_cents: 5, valid_from: Date.current, approved_by: @admin, approved_at: Time.current)
    assert_not rate.valid?
  end
end
