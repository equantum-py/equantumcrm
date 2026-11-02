require "test_helper"

class AgentRunTest < ActiveSupport::TestCase
  setup { @agent = Agent.find_by!(key: "lead_analyst") }

  test "a successful block is closed as succeeded" do
    result = AgentRun.track(@agent, trigger: "manual") { |run| run.leads_detected = 2; :ok }
    run = @agent.runs.first
    assert_equal :ok, result
    assert_equal [ "succeeded", 2 ], [ run.status, run.leads_detected ]
    assert run.finished_at
  end

  test "if the run cannot be created the work does not start" do
    executed = false
    assert_raises(ActiveRecord::RecordInvalid) do
      AgentRun.track(@agent, trigger: "por_las_dudas") { executed = true }
    end
    assert_not executed
  end

  test "a failing block is recorded and its error re-raised" do
    error = assert_raises(RuntimeError) { AgentRun.track(@agent, trigger: "manual") { raise "falló la fuente" } }
    assert_equal "falló la fuente", error.message
    run = @agent.runs.first
    assert_equal [ "failed", 1, [ "RuntimeError: falló la fuente" ] ], [ run.status, run.errors_count, run.error_messages ]
  end

  test "the original error survives when the failure cannot be recorded" do
    reported = []
    subscriber = Object.new
    subscriber.define_singleton_method(:report) { |error, **| reported << error }
    Rails.error.subscribe(subscriber)
    error = assert_raises(ArgumentError) do
      AgentRun.track(@agent, trigger: "manual") do |run|
        run.define_singleton_method(:update_columns) { |*| raise ActiveRecord::ConnectionNotEstablished, "sin base" }
        raise ArgumentError, "error original"
      end
    end
    assert_equal "error original", error.message
    assert(reported.any? { |e| e.is_a?(ActiveRecord::ConnectionNotEstablished) }, "el fallo de registro debe reportarse")
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  test "a run that cannot be closed raises instead of hiding it" do
    assert_raises(AgentRun::TrackingError) do
      AgentRun.track(@agent, trigger: "manual") { |run| run.leads_detected = -1 }
    end
  end

  test "error messages are sanitized before they are stored" do
    with_secret("PROSPECT_AI_TOKEN", "valor-secreto-del-entorno") do
      secrets = [
        "Authorization: Bearer abc.def-123",
        "GET https://usuario:clave@api.example.com/v1",
        "https://api.example.com/x?api_key=AAA111&page=2",
        "token=zzz password: hunter22",
        "cliente eqcrm_7Xy9AbCdEfGhJkLmNpQr no válido",
        "escribir a juan.perez@example.com",
        "falló con valor-secreto-del-entorno"
      ]
      error = assert_raises(RuntimeError) { AgentRun.track(@agent, trigger: "manual") { raise secrets.join(" | ") } }
      stored = @agent.runs.first.error_messages.last
      assert error.message.include?("hunter22"), "el error original no se modifica"
      %w[abc.def-123 clave AAA111 zzz hunter22 7Xy9AbCdEfGhJkLmNpQr juan.perez valor-secreto-del-entorno].each do |secret|
        assert_not_includes stored, secret
      end
      assert_includes stored, "[FILTRADO]"
      assert_operator stored.length, :<=, AgentRun::MAX_ERROR_LENGTH
    end
  end

  test "source urls are stored without credentials" do
    AgentRun.track(@agent, trigger: "manual", source_url: "https://u:p@example.com/feed?token=abc") { nil }
    assert_equal "https://[FILTRADO]@example.com/feed?token=[FILTRADO]", @agent.runs.first.source_url
  end

  private
    def with_secret(name, value)
      previous = ENV[name]
      ENV[name] = value
      yield
    ensure
      ENV[name] = previous
    end
end
