require "test_helper"

class AnalyzeLeadJobTest < ActiveJob::TestCase
  class FakeClient
    def initialize(response) = @response = response
    def analyze(_lead) = @response
  end

  test "stores the proposal as pending review" do
    lead = create_lead
    fake = FakeClient.new({ "engine_version" => "rules-test", "services" => [ "seo" ],
                            "criteria" => [ { "key" => "explicit_intent", "points" => 10, "basis" => "inferred" } ] })
    with_env("PROSPECT_AI_URL" => "http://prospect-ai.test", "PROSPECT_AI_TOKEN" => "x") do
      original = AnalyzeLeadJob.client_builder
      AnalyzeLeadJob.client_builder = -> { fake }
      AnalyzeLeadJob.perform_now(lead)
    ensure
      AnalyzeLeadJob.client_builder = original
    end
    analysis = lead.ai_analyses.sole
    assert_equal "pending_review", analysis.status
    assert_equal [ "seo" ], analysis.service_keys
    assert_nil lead.reload.score
  end

  test "records the run in Agent Control" do
    lead = create_lead
    fake = FakeClient.new({ "engine_version" => "rules-test", "criteria" => [] })
    with_fake_client(fake) { AnalyzeLeadJob.perform_now(lead) }
    run = Agent.find_by!(key: "lead_analyst").runs.first
    assert_equal [ "succeeded", "event", lead ], [ run.status, run.trigger, run.subject ]
    assert_equal 1, run.pending_approvals
  end

  test "a disabled analyst agent does not run" do
    Agent.find_by!(key: "lead_analyst").update!(enabled: false)
    lead = create_lead
    with_fake_client(FakeClient.new({ "criteria" => [] })) { AnalyzeLeadJob.perform_now(lead) }
    assert_empty lead.ai_analyses
  ensure
    Agent.find_by!(key: "lead_analyst").update!(enabled: true)
  end

  test "does nothing when Prospect AI is not configured" do
    lead = create_lead
    with_env("PROSPECT_AI_URL" => nil, "PROSPECT_AI_TOKEN" => nil) { AnalyzeLeadJob.perform_now(lead) }
    assert_empty lead.ai_analyses
  end

  test "request carries the active rubric and catalogs" do
    request = ProspectAiClient.analyze_request(create_lead)
    assert_equal ScoringCriterion.current.pluck(:key), request[:rubric].map { |c| c[:key] }
    assert_includes request[:target_countries], "PY"
  end

  private
    def with_fake_client(fake)
      with_env("PROSPECT_AI_URL" => "http://prospect-ai.test", "PROSPECT_AI_TOKEN" => "x") do
        original = AnalyzeLeadJob.client_builder
        AnalyzeLeadJob.client_builder = -> { fake }
        yield
      ensure
        AnalyzeLeadJob.client_builder = original
      end
    end

    def with_env(values)
      previous = values.keys.index_with { |key| ENV[key] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous.each { |key, value| ENV[key] = value }
    end
end
