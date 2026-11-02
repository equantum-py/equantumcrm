require "test_helper"

class ArmPendingActivitiesTest < ActiveSupport::TestCase
  setup do
    @owner = create_user
    @other = create_user
    real_lead = create_lead
    synthetic_lead = create_lead(title: "Prueba marcada sin prefijo", synthetic: true)
    legacy_lead = create_lead
    legacy_lead.update_columns(title: "[SINTÉTICO] Registro heredado", synthetic: false)
    real_opportunity = create_opportunity(owner: @owner, lead: real_lead)
    synthetic_opportunity = create_opportunity(owner: @owner, lead: synthetic_lead)
    legacy_opportunity = create_opportunity(owner: @owner, lead: legacy_lead)

    @future_lead = activity(real_lead, due_at: 10.minutes.from_now)
    @future_opportunity = activity(real_opportunity, due_at: 20.minutes.from_now)
    @future_company = activity(create_company, due_at: 30.minutes.from_now)
    @other_activity = activity(real_lead, owner: @other, due_at: 40.minutes.from_now)
    @undated = activity(real_lead, due_at: nil)
    @overdue = activity(real_lead, due_at: 1.hour.ago)
    @completed = activity(real_lead, due_at: 1.hour.from_now, completed_at: Time.current)
    @synthetic_activities = [ synthetic_lead, legacy_lead, synthetic_opportunity, legacy_opportunity ].map do |subject|
      activity(subject, due_at: 5.minutes.from_now)
    end
    @synthetic_activities << activity(synthetic_lead, due_at: nil)
    @synthetic_activities << activity(synthetic_opportunity, due_at: 2.hours.ago)
  end

  test "upcoming activity count excludes canonical test data and preserves owner and due-date semantics" do
    assert_equal 4, DashboardMetrics.new.upcoming_activities_count
    assert_equal 3, DashboardMetrics.new(owner_id: @owner.id).upcoming_activities_count
    assert_equal 1, DashboardMetrics.new(owner_id: @other.id).upcoming_activities_count
    assert_equal 0, DashboardMetrics.new(owner_id: -1).upcoming_activities_count
  end

  test "pending activity preview excludes synthetic subjects while preserving ordering and owner" do
    preview = DashboardMetrics.new(owner_id: @owner.id).pending_activities_preview.to_a
    assert_equal [ @overdue.id, @future_lead.id, @future_opportunity.id, @future_company.id, @undated.id ], preview.map(&:id)
    assert_empty preview.map(&:id) & @synthetic_activities.map(&:id)
    assert_not_includes preview.map(&:id), @completed.id
    assert_not_includes preview.map(&:id), @other_activity.id
    assert preview.all? { |row| row.association(:owner).loaded? && row.association(:subject).loaded? }
    assert_equal [ @other_activity.id ], DashboardMetrics.new(owner_id: @other.id).pending_activities_preview.map(&:id)

    # The presentation limit is applied after filtering test data.
    7.times { activity(@future_lead.subject, due_at: 2.days.from_now) }
    assert_equal 6, DashboardMetrics.new(owner_id: @owner.id).pending_activities_preview.size
  end

  private
    def activity(subject, owner: @owner, due_at:, completed_at: nil)
      Activity.create!(subject: subject, owner: owner, kind: "follow_up", title: "Seguimiento de prueba",
                       due_at: due_at, completed_at: completed_at)
    end
end
