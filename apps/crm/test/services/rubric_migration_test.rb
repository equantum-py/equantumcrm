require "test_helper"

class RubricMigrationTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(role: "admin")
    @lead = create_lead(urgency: "high")
    @lead.services = Service.where(key: "ecommerce")
    score_all!(@lead)
  end

  test "seeds keep v1 active and v2 as a draft" do
    assert_equal 1, RubricVersion.active_version
    assert_equal "draft", RubricVersion.find_by!(version: 2).status
    assert_equal 1, ScoringCriterion.current_version
    assert_equal 100, ScoringCriterion.where(version: 2).sum(:max_points)
  end

  test "preview writes nothing" do
    rows = nil
    assert_no_difference -> { LeadScore.count } do
      rows = RubricMigration.new(from: 1, to: 2).preview
    end
    row = rows.find { |r| r.lead == @lead }
    assert_equal 100, row.old_score
    assert_equal 100, row.new_score
    assert_nil @lead.reload.commercial_priority
    assert_equal 1, RubricVersion.active_version
  end

  test "activation rescales shared criteria, drops moved ones and computes priority" do
    RubricMigration.new(from: 1, to: 2).activate!(approved_by: @admin)
    @lead.reload
    assert_equal 2, RubricVersion.active_version
    assert_equal "retired", RubricVersion.find_by!(version: 1).status
    assert_equal 2, @lead.scoring_version
    assert_equal 100, @lead.score
    intent = @lead.lead_scores.joins(:scoring_criterion).find_by(scoring_criteria: { version: 2, key: "explicit_intent" })
    assert_equal 30, intent.points
    assert_includes intent.justification, "reescalado"
    assert_not_nil @lead.commercial_priority
    assert AuditLog.exists?(action: "rubric_activated")
  end

  test "activation requires an approver" do
    assert_raises(ArgumentError) { RubricMigration.new(from: 1, to: 2).activate!(approved_by: nil) }
    assert_equal 1, RubricVersion.active_version
  end
end
