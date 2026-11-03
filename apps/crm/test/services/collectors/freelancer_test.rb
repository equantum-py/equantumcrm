require "test_helper"

class Collectors::FreelancerTest < ActiveSupport::TestCase
  setup do
    @agent = Agent.find_by!(key: "prospect_scout")
    @agent.update!(enabled: true)
  end

  teardown { @agent.update!(enabled: false) }

  def project(id: 101, title: "Tienda Shopify para marca de ropa", jobs: [ "Shopify", "eCommerce" ], **extra)
    {
      "id" => id, "title" => title, "seo_url" => "shopify/Tienda-Shopify-#{id}", "status" => "active",
      "frontend_project_status" => "open", "deleted" => false, "nonpublic" => false, "hireme" => false,
      "description" => "Necesito una tienda Shopify con 30 productos y pasarela de pago.", "type" => "fixed",
      "currency" => { "code" => "USD" }, "budget" => { "minimum" => 250.0, "maximum" => 750.0 },
      "bid_stats" => { "bid_count" => 7 }, "time_submitted" => 1.day.ago.to_i, "bidperiod" => 7,
      "jobs" => jobs.map { |name| { "name" => name } }
    }.merge(extra.transform_keys(&:to_s))
  end

  def response_with(*projects) = [ 200, { "status" => "success", "result" => { "projects" => projects } }.to_json ]

  def collector(responses, **options)
    requests = []
    http = lambda do |url|
      requests << url
      responses.is_a?(Proc) ? responses.call(url) : (responses.shift || response_with)
    end
    sleeps = []
    instance = Collectors::Freelancer.new(http: http, sleeper: ->(s) { sleeps << s }, clock: -> { 0.0 },
                                          queries: %w[shopify seo], **options)
    [ instance, requests, sleeps ]
  end

  test "normalizes a project into an unverified lead payload with evidence and date" do
    candidate = Collectors::Freelancer.normalize(project, captured_at: Time.zone.parse("2026-11-02 10:00"))
    payload = candidate.payload
    assert_equal "freelancer", payload["source"]
    assert_equal "freelancer:101", payload["external_id"]
    assert_equal "https://www.freelancer.com/projects/shopify/Tienda-Shopify-101", payload["original_url"]
    assert_equal "USD 250–750 (precio fijo)", payload["published_budget_text"]
    assert_equal 7, payload["competition_count"]
    assert payload["published_at_verified"]
    assert_match "Freelancer API 2026-11-02", payload["evidence"].first["excerpt"]
    assert_equal %w[shopify ecommerce], candidate.service_keys
  end

  test "keeps only open public projects of eQuantum services" do
    assert_nil Collectors::Freelancer.normalize(project(jobs: [ "Data Entry", "Excel" ]))
    assert_nil Collectors::Freelancer.normalize(project(nonpublic: true))
    assert_nil Collectors::Freelancer.normalize(project(hireme: true))
    assert_nil Collectors::Freelancer.normalize(project(frontend_project_status: "closed", status: "closed"))
    assert_nil Collectors::Freelancer.normalize(project(seo_url: "../../evil"))
  end

  test "ingests new projects as unverified leads, links services and records the run" do
    instance, requests, = collector([ response_with(project, project(id: 102, jobs: [ "Excel" ])), response_with(project) ])
    summary = instance.call

    lead = Lead.find_by!(external_id: "freelancer:101")
    assert_equal [ "unverified", "new", "api" ], [ lead.verification_status, lead.status, lead.created_via ]
    assert_nil lead.score
    assert_equal %w[ecommerce shopify], lead.services.pluck(:key).sort
    assert_equal 1, lead.lead_evidences.count
    assert_equal 1, summary.created
    assert_equal 2, requests.size
    assert(requests.all? { |url| url.start_with?(Collectors::Freelancer::ENDPOINT) && url.include?("languages[]=es") })

    run = @agent.runs.first
    assert_equal [ "succeeded", "manual", "freelancer", 1, 0, 1 ], [ run.status, run.trigger, run.source_key, run.leads_detected, run.duplicates, run.pending_approvals ]
    assert_match "1 nuevos sin verificar", run.summary
  end

  test "a second run counts duplicates instead of creating them" do
    collector([ response_with(project) ]).first.call
    summary = collector([ response_with(project) ]).first.call
    assert_equal [ 0, 1 ], [ summary.created, summary.duplicates ]
    assert_equal 1, Lead.where(external_id: "freelancer:101").count
  end

  test "dry run reads but registers nothing" do
    summary = collector([ response_with(project) ], dry_run: true).first.call
    assert_equal 1, summary.candidates.size
    assert_not Lead.exists?(external_id: "freelancer:101")
    assert_match "Simulación", @agent.runs.first.summary
  end

  test "respects the request limit and the minimum interval" do
    instance, requests, sleeps = collector(->(_url) { response_with }, max_requests: 3, queries: %w[a b c d e], min_interval: 2.0)
    instance.call
    assert_equal 3, requests.size
    assert_equal [ 2.0, 2.0 ], sleeps
  end

  test "a 429 stops the run and is recorded" do
    instance, requests, = collector([ response_with(project), [ 429, "" ], response_with(project(id: 103)) ], queries: %w[shopify seo ads])
    summary = instance.call
    assert_equal 2, requests.size
    assert_equal 1, summary.created
    assert_match "429", summary.errors.first
    assert_equal 1, @agent.runs.first.errors_count
  end

  test "source errors are recorded, sanitized and do not stop other queries" do
    responses = [ [ 500, "" ], [ 200, "no es json" ], response_with(project) ]
    failing = lambda do |url|
      raise SocketError, "fallo al abrir #{url}&token=secreto123" if url.include?("query=seo")

      responses.shift
    end
    instance, = collector(failing, queries: %w[shopify seo ads web])
    summary = instance.call
    run = @agent.runs.first
    assert_equal [ "succeeded", 1 ], [ run.status, summary.created ]
    assert_equal 3, run.errors_count
    assert_match "500", summary.errors.first
    assert_not(run.error_messages.any? { |m| m.include?("secreto123") })
  end

  test "a run where every query fails is marked failed" do
    instance, = collector([ [ 503, "" ], [ 503, "" ] ])
    assert_raises(Collectors::Freelancer::FetchError) { instance.call }
    run = @agent.runs.first
    assert_equal "failed", run.status
    assert_equal 3, run.errors_count
  end

  test "a disabled agent cannot read or ingest" do
    @agent.update!(enabled: false)
    instance, requests, = collector([ response_with(project) ])
    assert_raises(Agent::NotAuthorized) { instance.call }
    assert_empty requests
    assert_not Lead.exists?(external_id: "freelancer:101")
  end

  test "without the ingest action it can only simulate" do
    @agent.update!(allowed_actions: %w[read_public_sources])
    assert_raises(Agent::NotAuthorized) { collector([ response_with(project) ]).first.call }
    assert collector([ response_with(project) ], dry_run: true).first.call
  ensure
    @agent.update!(allowed_actions: %w[read_public_sources ingest_leads])
  end

  test "no recurring task runs the collector" do
    recurring = Rails.root.join("config/recurring.yml").read
    assert_no_match(/Freelancer|collect_freelancer|prospect_scout/, recurring)
  end
end
