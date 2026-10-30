require "net/http"

# Calls the stateless Prospect AI service. Rails sends the active rubric and
# catalog so Python never needs its own copy of commercial data.
class ProspectAiClient
  class Error < StandardError; end

  TIMEOUT = 10

  def self.configured? = ENV["PROSPECT_AI_URL"].present? && ENV["PROSPECT_AI_TOKEN"].present?

  def initialize(base_url: ENV.fetch("PROSPECT_AI_URL"), token: ENV.fetch("PROSPECT_AI_TOKEN"))
    @base_url = base_url
    @token = token
  end

  def analyze(lead)
    post("/v1/analyze", self.class.analyze_request(lead))
  end

  def self.analyze_request(lead)
    {
      source: lead.source.key,
      original_url: lead.original_url,
      text: lead.need_summary.presence || lead.title,
      country_hint: lead.country&.iso2,
      published_at: lead.published_at&.iso8601,
      published_at_verified: lead.published_at_verified,
      published_budget_text: lead.published_budget_text,
      rubric: ScoringCriterion.current.map { |c| { key: c.key, max_points: c.max_points } },
      services: Service.active.pluck(:key),
      target_countries: Country.where(target_market: true).pluck(:iso2)
    }
  end

  private
    def post(path, body)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{@token}")
      request.body = body.to_json
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(request)
      end
      raise Error, "Prospect AI respondió #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "Prospect AI no disponible: #{e.class}"
    end
end
