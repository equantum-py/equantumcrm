# Asks Prospect AI for a proposal on a manually captured lead and stores it
# as pending review. If the service is down the lead stays usable by hand.
class AnalyzeLeadJob < ApplicationJob
  queue_as :default
  retry_on ProspectAiClient::Error, wait: :polynomially_longer, attempts: 5

  class_attribute :client_builder, default: -> { ProspectAiClient.new }

  def perform(lead)
    return unless ProspectAiClient.configured?
    return if lead.ai_analyses.where(provider: "prospect_ai:job").pending.exists?
    return if agent && !agent.enabled

    track(lead) do |run|
      raw = client_builder.call.analyze(lead)
      output = LeadAnalysisImport.new(raw.to_json).call
      lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job",
                               engine_version: raw["engine_version"].to_s.presence || "desconocida", output: output)
      run&.update!(pending_approvals: 1, summary: "Propuesta de análisis guardada para revisión")
    end
  end

  private
    # Records the run in Agent Control when the agent is registered.
    def agent = @agent ||= Agent.find_by(key: "lead_analyst")

    def track(lead, &block)
      return yield(nil) unless agent

      AgentRun.track(agent, trigger: "event", subject: lead, source_key: "prospect_ai", &block)
    end
end
