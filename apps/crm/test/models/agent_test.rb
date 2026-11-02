require "test_helper"

class AgentTest < ActiveSupport::TestCase
  def build_agent(**attrs)
    Agent.new({ key: "agente_prueba", name: "Agente de prueba", area: "prospect_ai", allowed_actions: %w[read_public_sources] }.merge(attrs))
  end

  test "commercial actions can never be granted" do
    Agent::FORBIDDEN_ACTIONS.each_key do |action|
      agent = build_agent(allowed_actions: [ "draft_messages", action ])
      assert_not agent.valid?, "#{action} no debería poder asignarse"
      assert_match "acciones prohibidas", agent.errors[:allowed_actions].join
    end
  end

  test "unknown actions are rejected" do
    agent = build_agent(allowed_actions: %w[scrape_everything])
    assert_not agent.valid?
    assert_match "desconocidas", agent.errors[:allowed_actions].join
  end

  test "a scheduled agent needs a schedule" do
    assert_not build_agent(execution_mode: "scheduled").valid?
    assert build_agent(execution_mode: "scheduled", schedule: "cada día a las 8:00").valid?
  end

  test "operating state never claims autonomy that does not exist" do
    assert_equal :disabled, build_agent(enabled: false).operating_state
    assert_equal :not_implemented, build_agent(enabled: true, implemented_by: nil).operating_state
    assert_equal :manual, build_agent(enabled: true, implemented_by: "AnalyzeLeadJob").operating_state
  end

  test "seeded catalog starts with only the existing analyst enabled and no forbidden actions" do
    assert Agent.find_by!(key: "lead_analyst").enabled
    assert_equal [ "lead_analyst" ], Agent.where(enabled: true).pluck(:key)
    assert(Agent.all.none? { |agent| (agent.allowed_actions & Agent::FORBIDDEN_ACTIONS.keys).any? })
  end

  test "track records duration, counts and failures" do
    agent = Agent.find_by!(key: "lead_analyst")
    AgentRun.track(agent, trigger: "manual", source_key: "prueba") { |run| run.update!(leads_detected: 3, duplicates: 1) }
    run = agent.runs.first
    assert_equal "succeeded", run.status
    assert_equal [ 3, 1 ], [ run.leads_detected, run.duplicates ]
    assert run.duration

    assert_raises(RuntimeError) { AgentRun.track(agent, trigger: "manual") { raise "fuente caída" } }
    failed = agent.runs.reload.first
    assert_equal "failed", failed.status
    assert_equal 1, failed.errors_count
    assert_match "fuente caída", failed.error_messages.first
  end
end
