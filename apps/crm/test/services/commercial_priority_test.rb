require "test_helper"

# Amounts here are synthetic test fixtures, not approved rates or thresholds.
class CommercialPriorityTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(role: "admin")
    @now = Time.zone.parse("2026-10-30 12:00")
  end

  def lead_with(services: %w[app_web], **attrs)
    lead = create_lead(**attrs)
    lead.services = Service.where(key: services)
    lead
  end

  def priority(lead) = CommercialPriority.new(lead, on: @now).call

  def threshold!(currency, min, high)
    CommercialThreshold.create!(currency: currency, min_viable_cents: min * 100, high_value_cents: high * 100, approved_by: @admin, approved_at: @now)
  end

  def rate!(service_key, currency, min, max, unit: "project")
    ServiceRate.create!(service: Service.find_by!(key: service_key), currency: currency, unit: unit, min_cents: min * 100,
                        max_cents: max * 100, valid_from: @now.to_date - 1, approved_by: @admin, approved_at: @now)
  end

  test "a EUR 20 job no longer outranks a USD 5,000 project once thresholds exist" do
    threshold!("EUR", 300, 2000)
    threshold!("USD", 300, 2000)
    small = lead_with(services: %w[web_corporativa], urgency: "high", published_at: @now - 1.hour,
                      budget_currency: "EUR", budget_min_cents: 1000, budget_max_cents: 2000, competition_count: 3)
    big = lead_with(services: %w[app_web], urgency: "unknown", published_at: @now - 2.days,
                    budget_currency: "USD", budget_min_cents: 300_000, budget_max_cents: 500_000, competition_count: 156)

    assert_equal "not_recommended", priority(small).priority
    assert_includes priority(small).breakdown["blockers"].join, "mínimo viable"
    assert_includes %w[high medium], priority(big).priority
  end

  test "missing data is excluded, not assumed, and caps the class at medium" do
    lead = lead_with(services: %w[shopify], urgency: "high", published_at: @now - 1.hour, competition_count: 2)
    result = priority(lead)
    excluded = result.breakdown["excluded"].map { |item| item["key"] }
    assert_equal %w[budget_vs_rate economic_value profitability], excluded
    assert_equal 0.4 + 0.0, result.confidence.to_f
    assert_equal 100, result.score
    assert_equal "medium", result.priority
    assert result.breakdown["capped_by_confidence"]
  end

  test "profitability is only evaluated with an approved rate" do
    lead = lead_with(services: %w[ecommerce], budget_currency: "EUR", budget_min_cents: 50_000, budget_max_cents: 100_000)
    assert_includes priority(lead).breakdown["excluded"].map { |i| i["key"] }, "profitability"

    rate!("ecommerce", "EUR", 600, 1200)
    factors = priority(lead).breakdown["factors"].index_by { |f| f["key"] }
    assert_equal 0.5, factors["budget_vs_rate"]["fraction"]
    assert_equal 0.3, factors["profitability"]["fraction"]
  end

  test "hourly rates need estimated hours" do
    rate!("app_web", "USD", 20, 40, unit: "hour")
    lead = lead_with(budget_currency: "USD", budget_min_cents: 300_000, budget_max_cents: 500_000)
    assert_includes priority(lead).breakdown["excluded"].map { |i| i["key"] }, "profitability"

    lead.update!(estimated_hours: 100)
    factors = priority(lead).breakdown["factors"].index_by { |f| f["key"] }
    assert_equal 1, factors["budget_vs_rate"]["fraction"]
    assert_equal 1, factors["profitability"]["fraction"]
  end

  test "budget far below the approved rate is not recommended" do
    rate!("shopify", "EUR", 1000, 2000)
    lead = lead_with(services: %w[shopify], budget_currency: "EUR", budget_min_cents: 10_000, budget_max_cents: 40_000)
    assert_equal "not_recommended", priority(lead).priority
  end

  test "hard blockers" do
    assert_equal "not_recommended", priority(lead_with(services: [])).priority
    assert_equal "not_recommended", priority(lead_with(listing_closed: true)).priority
    assert_equal "not_recommended", priority(lead_with(deadline_at: @now - 1.day)).priority
    assert_equal "not_recommended", priority(lead_with(country: Country.find_by!(iso2: "MX"))).priority
  end

  test "zero intent blocks the lead" do
    lead = lead_with
    lead.lead_scores.create!(scoring_criterion: ScoringCriterion.current.find_by!(key: "explicit_intent"), points: 0, basis: "verified")
    assert_includes priority(lead).breakdown["blockers"], "Sin intención de contratación"
  end

  test "recurring services gain value" do
    seo = priority(lead_with(services: %w[seo])).breakdown["factors"].find { |f| f["key"] == "service_value" }
    ux = priority(lead_with(services: %w[ux_ui])).breakdown["factors"].find { |f| f["key"] == "service_value" }
    assert_operator seo["fraction"], :>, ux["fraction"]
  end

  test "lead stores nothing while v2 is a draft" do
    lead = lead_with(budget_currency: "USD", budget_min_cents: 100, budget_max_cents: 200)
    lead.refresh_priority!
    assert_nil lead.reload.commercial_priority
  end

  test "budget needs currency and both amounts" do
    lead = Lead.new(title: "x", source: Source.find_by!(key: "manual"), need_summary: "y", budget_currency: "USD", budget_min_cents: 100)
    refute lead.valid?
    assert lead.errors[:budget_currency].any?
  end
end
