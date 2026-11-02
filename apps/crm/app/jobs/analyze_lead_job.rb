# Asks Prospect AI for a proposal on a manually captured lead and stores it
# as pending review. If the service is down the lead stays usable by hand.
#
# It only runs while the lead_analyst agent exists, is enabled and is allowed
# to analyze leads. A fresh database (before db:seed) has no agent, so nothing
# runs automatically until the catalog is loaded on purpose.
class AnalyzeLeadJob < ApplicationJob
  AGENT_KEY = "lead_analyst".freeze
  ACTION = "analyze_leads".freeze

  queue_as :default
  retry_on ProspectAiClient::Error, wait: :polynomially_longer, attempts: 5

  class_attribute :client_builder, default: -> { ProspectAiClient.new }

  # Checked before enqueuing, so a switched-off agent does not queue work.
  def self.runnable?
    ProspectAiClient.configured? && Agent.find_by(key: AGENT_KEY)&.allowed_to?(ACTION)
  end

  def perform(lead)
    return unless ProspectAiClient.configured?

    agent = Agent.find_by(key: AGENT_KEY)
    unless agent&.enabled
      Rails.logger.info("[AnalyzeLeadJob] #{AGENT_KEY} #{agent ? 'desactivado' : 'no registrado'}: no se analiza el prospecto #{lead.id}")
      return
    end
    agent.authorize!(ACTION)
    return if lead.ai_analyses.where(provider: "prospect_ai:job").pending.exists?

    AgentRun.track(agent, trigger: "event", subject: lead, source_key: "prospect_ai") do |run|
      raw = client_builder.call.analyze(lead)
      output = LeadAnalysisImport.new(raw.to_json).call
      Agent.authorize!(AGENT_KEY, ACTION) # the switch may have been turned off during the call
      lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job",
                               engine_version: raw["engine_version"].to_s.presence || "desconocida", output: output)
      run.update!(pending_approvals: 1, summary: "Propuesta de análisis guardada para revisión")
    end
  end
end
