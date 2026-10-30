require "test_helper"

class LeadTest < ActiveSupport::TestCase
  test "same post through different URL variants is a duplicate" do
    create_lead(original_url: "https://www.facebook.com/groups/1/posts/2/")
    duplicate = Lead.new(title: "Otra", source: Source.find_by!(key: "facebook_group"), original_url: "https://m.facebook.com/groups/1/posts/2?mibextid=z")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:fingerprint], "coincide con un prospecto ya registrado"
  end

  test "without url the fingerprint uses normalized text" do
    create_lead(need_summary: "Busco quien haga una TIENDA online!!")
    duplicate = Lead.new(title: "x", source: Source.find_by!(key: "manual"), need_summary: "busco quien haga una tienda online")
    assert_not duplicate.valid?
  end

  test "score is set only when every criterion is scored and band follows the rubric" do
    lead = create_lead
    criterion = ScoringCriterion.current.first
    lead.lead_scores.create!(scoring_criterion: criterion, points: 25, basis: "verified")
    lead.recalculate_score!
    assert_nil lead.score

    lead.lead_scores.destroy_all
    score_all!(lead, points: 5)
    assert_equal 40, lead.reload.score
    assert_equal "medium", lead.score_band
  end

  test "points cannot exceed the criterion maximum" do
    lead = create_lead
    criterion = ScoringCriterion.current.find_by!(key: "budget")
    score = lead.lead_scores.build(scoring_criterion: criterion, points: 6, basis: "verified")
    assert_not score.valid?
  end

  test "qualifying requires verified source and complete score" do
    lead = create_lead
    assert_not lead.update(status: "qualified")
    lead.reload.update!(verification_status: "verified")
    score_all!(lead)
    assert lead.reload.update(status: "qualified")
  end

  test "discarding requires a reason" do
    lead = create_lead
    assert_not lead.update(status: "discarded")
    assert lead.update(status: "discarded", discard_reason: "Es una oferta de servicios")
  end

  test "changes are audited" do
    lead = create_lead
    assert AuditLog.exists?(auditable: lead, action: "create")
    lead.update!(title: "Nuevo título")
    assert AuditLog.exists?(auditable: lead, action: "update")
  end
end
