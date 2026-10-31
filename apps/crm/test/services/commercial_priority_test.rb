require "test_helper"

# Rates here are synthetic test fixtures, not approved prices. Thresholds
# come from the seeds (Dirección's initial classification values).
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
  def factors(lead) = priority(lead).breakdown["factors"].index_by { |f| f["key"] }
  def excluded(lead) = priority(lead).breakdown["excluded"].map { |item| item["key"] }

  def approved_rate!(service_key, currency, min, max, unit: "project")
    ServiceRate.create!(service: Service.find_by!(key: service_key), currency: currency, unit: unit, min_cents: min * 100,
                        max_cents: max * 100, valid_from: @now.to_date - 1, status: "approved", approved_by: @admin, approved_at: @now)
  end

  test "seeds load Dirección's initial classification thresholds" do
    usd = CommercialThreshold.find_by!(currency: "USD")
    assert_equal [ 50_000, 200_000 ], [ usd.medium_from_cents, usd.high_from_cents ]
    assert_equal [ 4_000_000, 15_000_000 ], CommercialThreshold.find_by!(currency: "PYG").values_at(:medium_from_cents, :high_from_cents)
    assert_equal [ 200_000_000, 800_000_000 ], CommercialThreshold.find_by!(currency: "COP").values_at(:medium_from_cents, :high_from_cents)
    assert_equal [ 500_000, 2_000_000 ], CommercialThreshold.find_by!(currency: "CLP").values_at(:medium_from_cents, :high_from_cents)
  end

  test "a EUR 20 job no longer outranks a USD 5,000 project" do
    small = lead_with(services: %w[ux_ui], urgency: "high", published_at: @now - 1.hour,
                      budget_currency: "EUR", budget_min_cents: 1500, budget_max_cents: 2000)
    big = lead_with(services: %w[app_web], published_at: @now - 9.hours,
                    budget_currency: "USD", budget_min_cents: 300_000, budget_max_cents: 500_000, competition_count: 156)

    assert_operator priority(big).score, :>, priority(small).score
    assert_equal "low", priority(small).breakdown["size_band"]
    assert_equal "high", priority(big).breakdown["size_band"]
  end

  test "a budget below the thresholds is classified low, never discarded" do
    lead = lead_with(services: %w[seo], budget_currency: "EUR", budget_min_cents: 800, budget_max_cents: 3000)
    result = priority(lead)
    assert_empty result.breakdown["blockers"]
    refute_equal "not_recommended", result.priority
    assert_equal 0.15, factors(lead)["economic_value"]["fraction"]
  end

  test "profitability stays unknown and lists what is missing" do
    approved_rate!("ecommerce", "EUR", 600, 1200)
    lead = lead_with(services: %w[ecommerce], budget_currency: "EUR", budget_min_cents: 50_000, budget_max_cents: 100_000, estimated_hours: 20)
    profitability = priority(lead).breakdown["profitability"]
    assert_equal "unknown", profitability["status"]
    assert_equal [ "costos internos verificables" ], profitability["missing"]

    bare = lead_with(services: %w[ecommerce])
    assert_equal 3, priority(bare).breakdown["profitability"]["missing"].size
  end

  test "only approved rates count" do
    pending = ServiceRate.create!(service: Service.find_by!(key: "ecommerce"), currency: "EUR", unit: "project", min_cents: 60_000,
                                  max_cents: 120_000, valid_from: @now.to_date - 1, status: "pending")
    lead = lead_with(services: %w[ecommerce], budget_currency: "EUR", budget_min_cents: 50_000, budget_max_cents: 100_000)
    assert_includes excluded(lead), "budget_vs_rate"

    pending.approve!(@admin)
    assert_equal 0.5, factors(lead)["budget_vs_rate"]["fraction"]
  end

  test "a budget under the approved rate raises an alert, not a block" do
    approved_rate!("shopify", "EUR", 1000, 2000)
    lead = lead_with(services: %w[shopify], budget_currency: "EUR", budget_min_cents: 10_000, budget_max_cents: 40_000)
    result = priority(lead)
    refute_equal "not_recommended", result.priority
    assert_match "no cubre la tarifa mínima", result.breakdown["alerts"].join
  end

  test "hourly rates need estimated hours" do
    approved_rate!("app_web", "USD", 20, 40, unit: "hour")
    lead = lead_with(budget_currency: "USD", budget_min_cents: 300_000, budget_max_cents: 500_000)
    assert_includes excluded(lead), "budget_vs_rate"
    lead.update!(estimated_hours: 100)
    assert_equal 1, factors(lead)["budget_vs_rate"]["fraction"]
  end

  test "missing data is excluded and low confidence caps the class at medium" do
    lead = lead_with(services: %w[shopify], urgency: "high", published_at: @now - 1.hour)
    result = priority(lead)
    assert_equal %w[economic_value budget_vs_rate competition], excluded(lead)
    assert_equal 0.25, result.confidence.to_f
    assert_equal "medium", result.priority
    assert result.breakdown["capped_by_confidence"]
  end

  test "hard blockers are facts, not money" do
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
    assert_operator factors(lead_with(services: %w[seo]))["service_value"]["fraction"], :>,
                    factors(lead_with(services: %w[ux_ui]))["service_value"]["fraction"]
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
