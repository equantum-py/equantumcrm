require "test_helper"

# Commercial indicators count only real data. Test or demo records
# (Lead.test_data) stay stored for validation and audit.
class SyntheticExclusionTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user(role: "manager")
    @real = create_lead(title: "Prospecto real")
    @flagged = create_lead(title: "Prospecto marcado", synthetic: true)
    @prefixed = create_lead(title: "[DEMO] Prospecto de demostración")
    @real_opp = create_opportunity(owner: @owner, lead: @real, name: "Oportunidad real")
    @test_opp = create_opportunity(owner: @owner, lead: @flagged, name: "Oportunidad de prueba")
  end

  def activity(subject, kind:, completed: false, due_at: nil, owner: @owner)
    Activity.create!(subject: subject, kind: kind, title: "#{kind} #{subject.class.name}", owner: owner,
                     completed_at: (Time.current if completed), due_at: due_at)
  end

  test "activity indicators count real leads, real opportunities and companies only" do
    activity(@real, kind: "call", completed: true)
    activity(@real_opp, kind: "meeting", completed: true)
    activity(@real_opp.company, kind: "follow_up", completed: true)
    activity(@real, kind: "task", due_at: 2.days.ago)
    activity(@flagged, kind: "call", completed: true)
    activity(@prefixed, kind: "meeting", completed: true)
    activity(@test_opp, kind: "meeting", completed: true)
    activity(@flagged, kind: "task", due_at: 2.days.ago)
    activity(@test_opp, kind: "task", due_at: 1.day.ago)

    metrics = DashboardMetrics.new
    assert_equal 3, metrics.contacted
    assert_equal 1, metrics.meetings
    assert_equal 1, metrics.overdue_activities
    assert_equal 5, Activity.test_data.count
    assert_equal 4, Activity.real.count
  end

  test "the owner filter still applies to activity indicators" do
    other = create_user(role: "sales")
    activity(@real, kind: "meeting", completed: true)
    activity(@real, kind: "meeting", completed: true, owner: other)
    activity(@real, kind: "task", due_at: 1.day.ago, owner: other)
    activity(@flagged, kind: "task", due_at: 1.day.ago, owner: other)

    assert_equal 2, DashboardMetrics.new.meetings
    assert_equal 1, DashboardMetrics.new(owner_id: other.id).meetings
    assert_equal 1, DashboardMetrics.new(owner_id: other.id).overdue_activities
    assert_equal 0, DashboardMetrics.new(owner_id: @owner.id).overdue_activities
  end

  test "opportunity indicators exclude opportunities of test leads" do
    assert_equal [ @real_opp ], Opportunity.real.where(id: [ @real_opp, @test_opp ]).to_a
    assert_equal [ @test_opp ], Opportunity.test_data.to_a
    total = DashboardMetrics.new.stage_breakdown.sum { |_stage, count| count }
    assert_equal Opportunity.real.count, total
  end

  test "Agent Control pending queues show real leads only" do
    real_api = create_lead(title: "Real por API", created_via: "api")
    create_lead(title: "Sintético por API", created_via: "api", synthetic: true)
    create_lead(title: "[SINTÉTICO] Por Skill", created_via: "skill")
    real_api.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    @flagged.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    @prefixed.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})

    assert_equal [ real_api.id ], AiAnalysis.pending.on_real_leads.pluck(:subject_id)
    sign_in create_user(role: "analyst")
    get agent_control_path
    assert_response :success
    assert_select "a", text: "Real por API"
    assert_select "a", text: "Prospecto marcado", count: 0
    assert_select "a", text: "[DEMO] Prospecto de demostración", count: 0
    assert_select "dd", text: /\A1\z/ # "Esperan aprobación"
    assert_select "p", text: /sin verificar: 1/
  end

  test "test data and its audit trail are kept, permissions and scoring untouched" do
    activity(@flagged, kind: "call", completed: true)
    @flagged.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job", output: {})
    audit_before = AuditLog.count
    permissions_before = Role.includes(:permissions).to_h { |role| [ role.key, role.permissions.map(&:key).sort ] }

    score_all!(@flagged)
    scored = @flagged.reload.score
    DashboardMetrics.new.then { |m| [ m.contacted, m.meetings, m.overdue_activities, m.pending_ai_reviews, m.leads_detected ] }
    sign_in create_user(role: "admin")
    get agent_control_path
    get root_path

    assert Lead.exists?(@flagged.id) && Lead.exists?(@prefixed.id)
    assert_equal 1, @flagged.activities.count
    assert_equal 1, @flagged.ai_analyses.count
    assert_operator AuditLog.count, :>=, audit_before
    assert AuditLog.where(auditable_type: "Lead", auditable_id: @flagged.id, action: "create").exists?
    assert_equal 100, scored, "el puntaje de un prospecto de prueba se calcula igual que siempre"
    assert_equal permissions_before.except("admin").keys.sort, Role.where.not(key: "admin").pluck(:key).sort
    assert_equal(permissions_before, Role.includes(:permissions).to_h { |role| [ role.key, role.permissions.map(&:key).sort ] })
  end
end
