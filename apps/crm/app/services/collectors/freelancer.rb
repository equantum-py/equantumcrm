require "net/http"

module Collectors
  # First real collector of the prospect_scout agent. Reads active public
  # projects from Freelancer's public API (no login, no scraping), keeps the
  # ones that match eQuantum services, normalizes them and ingests them as
  # UNVERIFIED leads. Every run is recorded in Agent Control.
  #
  # It never bids, contacts, prices or spends. It only runs when someone calls
  # it (rake agents:collect_freelancer); there is no recurring task.
  class Freelancer
    AGENT_KEY = "prospect_scout".freeze
    SOURCE_KEY = "freelancer".freeze
    ENDPOINT = "https://www.freelancer.com/api/projects/0.1/projects/active/".freeze
    PROJECT_URL = "https://www.freelancer.com/projects/".freeze
    USER_AGENT = "eQuantumARM-collector/1.0 (+https://www.equantum.com.py)".freeze

    # Search terms sent to the API. Results are kept only when one of their
    # Freelancer skills maps to an eQuantum service (JOB_SERVICES).
    QUERIES = [
      "shopify", "tienda online", "ecommerce", "woocommerce", "pagina web", "sitio web", "wordpress",
      "landing page", "seo", "google ads", "facebook ads", "meta ads", "aplicacion movil", "app",
      "automatizacion", "n8n", "integracion api", "google analytics"
    ].freeze

    JOB_SERVICES = {
      "Shopify" => %w[shopify ecommerce], "Shopify Templates" => %w[shopify], "Shopify Development" => %w[shopify],
      "eCommerce" => %w[ecommerce], "WooCommerce" => %w[ecommerce], "Magento" => %w[ecommerce], "PrestaShop" => %w[ecommerce],
      "Website Design" => %w[web_corporativa], "Web Development" => %w[web_corporativa], "WordPress" => %w[web_corporativa],
      "HTML" => %w[web_corporativa], "Landing Pages" => %w[landing], "Website Build" => %w[web_corporativa],
      "SEO" => %w[seo], "Google Ads" => %w[google_ads], "Google Adwords" => %w[google_ads],
      "Facebook Marketing" => %w[meta_ads], "Facebook Ads" => %w[meta_ads], "Social Media Marketing" => %w[meta_ads],
      "Mobile App Development" => %w[app_web], "Android" => %w[app_web], "iPhone" => %w[app_web], "Flutter" => %w[app_web],
      "React Native" => %w[app_web], "Web Application" => %w[app_web], "Laravel" => %w[app_web], "Ruby on Rails" => %w[app_web],
      "API" => %w[integraciones], "API Integration" => %w[integraciones], "Zapier" => %w[automatizacion], "n8n" => %w[automatizacion],
      "Automation" => %w[automatizacion], "UI / User Interface" => %w[ux_ui], "User Experience Design" => %w[ux_ui], "Figma" => %w[ux_ui],
      "Google Analytics" => %w[analitica_ga4], "Conversion Rate Optimization" => %w[cro]
    }.freeze

    DEFAULTS = { languages: %w[es], queries: QUERIES, per_query: 20, max_requests: 10, min_interval: 2.0, timeout: 15 }.freeze

    Candidate = Data.define(:project_id, :payload, :service_keys)
    Summary = Data.define(:fetched, :candidates, :created, :duplicates, :errors, :run)

    class RateLimited < StandardError; end
    class FetchError < StandardError; end

    def initialize(triggered_by: nil, trigger: "manual", dry_run: false, http: nil, sleeper: nil, clock: nil, **options)
      @triggered_by = triggered_by
      @trigger = trigger
      @dry_run = dry_run
      @options = DEFAULTS.merge(options)
      @http = http || method(:http_get)
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @requests = 0
      @successful_requests = 0
      @last_request_at = nil
    end

    def call
      agent = Agent.authorize!(AGENT_KEY, "read_public_sources")
      agent.authorize!("ingest_leads") unless @dry_run
      source = Source.find_by!(key: SOURCE_KEY)
      summary = nil

      AgentRun.track(agent, trigger: @trigger, triggered_by: @triggered_by, source_key: SOURCE_KEY, source_url: ENDPOINT) do |run|
        fetched, candidates = collect(run)
        raise FetchError, "Ninguna consulta a Freelancer respondió correctamente" if @requests.positive? && @successful_requests.zero?

        created, duplicates = @dry_run ? [ 0, 0 ] : ingest(agent, source, candidates, run)
        run.assign_attributes(leads_detected: created, duplicates: duplicates, pending_approvals: created,
                              summary: summary_text(fetched, candidates.size, created, duplicates))
        summary = Summary.new(fetched: fetched, candidates: candidates, created: created, duplicates: duplicates,
                              errors: run.error_messages, run: run)
      end
      summary
    end

    # Pure normalization: Freelancer project (API JSON) -> ingestion payload.
    # Returns nil when the project is not usable or not an eQuantum service.
    def self.normalize(project, captured_at: Time.current)
      return unless project.is_a?(Hash)
      return if project["deleted"] || project["nonpublic"] || project["hireme"]
      return unless project["frontend_project_status"].to_s == "open" || project["status"].to_s == "active"

      services = Array(project["jobs"]).flat_map { |job| JOB_SERVICES.fetch(job["name"].to_s, []) }.uniq
      return if services.empty?

      url = project_url(project)
      return unless url

      submitted = project["time_submitted"] || project["submitdate"]
      published_at = submitted && Time.zone.at(submitted.to_i)
      description = (project["description"].presence || project["preview_description"]).to_s.squish
      title = project["title"].to_s.squish.truncate(200)
      return if description.blank? && title.blank?

      payload = {
        "source" => SOURCE_KEY,
        "external_id" => "freelancer:#{project['id']}",
        "title" => title,
        "text_excerpt" => (description.presence || title).truncate(2000),
        "original_url" => url,
        "published_at" => published_at&.iso8601,
        "published_at_verified" => published_at.present?,
        "published_budget_text" => budget_text(project),
        "competition_count" => project.dig("bid_stats", "bid_count").is_a?(Integer) ? project.dig("bid_stats", "bid_count") : nil,
        "deadline_at" => (published_at && project["bidperiod"].to_i.positive? ? (published_at + project["bidperiod"].to_i.days).iso8601 : nil),
        "contact_channel" => { "kind" => "platform_message" },
        "evidence" => [ { "kind" => "page_snapshot", "captured_at" => captured_at.iso8601,
                          "excerpt" => "Freelancer API #{captured_at.to_date.iso8601}: #{title} · #{budget_text(project)} · " \
                                       "#{project.dig('bid_stats', 'bid_count') || 0} ofertas · skills: " \
                                       "#{Array(project['jobs']).map { |j| j['name'] }.join(', ')}".truncate(1000) } ]
      }.compact
      Candidate.new(project_id: project["id"], payload: payload, service_keys: services)
    end

    def self.project_url(project)
      slug = project["seo_url"].to_s
      return if slug.blank? || slug.match?(%r{\A/|\.\.|[^A-Za-z0-9_\-/]})

      "#{PROJECT_URL}#{slug}"
    end

    def self.budget_text(project)
      currency = project.dig("currency", "code").to_s.presence || "?"
      min = project.dig("budget", "minimum")
      max = project.dig("budget", "maximum")
      kind = project["type"] == "hourly" ? "por hora" : "precio fijo"
      range = [ min, max ].compact.map { |v| v.to_f.round.to_s }.uniq.join("–").presence || "sin presupuesto"
      "#{currency} #{range} (#{kind})"
    end

    private
      def collect(run)
        seen = {}
        fetched = 0
        @options[:queries].each do |query|
          break if @requests >= @options[:max_requests]

          projects = fetch(query, run)
          fetched += projects.size
          projects.each do |project|
            candidate = self.class.normalize(project)
            seen[candidate.project_id] ||= candidate if candidate
          end
        rescue RateLimited => e
          run.add_error(e)
          break
        end
        [ fetched, seen.values ]
      end

      def fetch(query, run)
        throttle
        @requests += 1
        params = { query: query, limit: @options[:per_query], job_details: true, full_description: true, compact: true }
        url = "#{ENDPOINT}?#{params.to_query}&#{@options[:languages].map { |l| "languages[]=#{CGI.escape(l)}" }.join('&')}"
        status, body = @http.call(url)
        raise RateLimited, "Freelancer limitó las solicitudes (429). Se detiene la ejecución." if status.to_i == 429
        raise FetchError, "Freelancer respondió #{status} para '#{query}'" unless status.to_i == 200

        data = JSON.parse(body.to_s)
        @successful_requests += 1
        Array(data.dig("result", "projects"))
      rescue JSON::ParserError, FetchError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
        run.add_error(e)
        []
      end

      def throttle
        if @last_request_at
          wait = @options[:min_interval] - (@clock.call - @last_request_at)
          @sleeper.call(wait) if wait.positive?
        end
        @last_request_at = @clock.call
      end

      def ingest(agent, source, candidates, run)
        created = 0
        duplicates = 0
        candidates.each do |candidate|
          agent.authorize!("ingest_leads") # honor a switch turned off mid-run
          result = LeadIngestion.new(candidate.payload, api_client: nil).call
          case result.status
          when 201
            created += 1
            attach_services(result.lead, candidate.service_keys)
          when 200 then duplicates += 1
          else run.add_error("#{candidate.payload['external_id']}: #{result.body.dig('error', 'details').to_json}")
          end
        end
        [ created, duplicates ]
      end

      def attach_services(lead, keys)
        Service.where(key: keys).find_each { |service| lead.lead_services.find_or_create_by!(service: service) }
      end

      def summary_text(fetched, candidates, created, duplicates)
        prefix = @dry_run ? "Simulación (no se registró nada): " : ""
        "#{prefix}#{@requests} consultas, #{fetched} proyectos leídos, #{candidates} de servicios eQuantum, " \
          "#{created} nuevos sin verificar, #{duplicates} ya registrados"
      end

      def http_get(url)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: @options[:timeout], read_timeout: @options[:timeout]) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "application/json"
          response = http.request(request)
          [ response.code.to_i, response.body ]
        end
      end
  end
end
