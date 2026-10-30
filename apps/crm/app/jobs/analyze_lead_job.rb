# Asks Prospect AI for a proposal on a manually captured lead and stores it
# as pending review. If the service is down the lead stays usable by hand.
class AnalyzeLeadJob < ApplicationJob
  queue_as :default
  retry_on ProspectAiClient::Error, wait: :polynomially_longer, attempts: 5

  class_attribute :client_builder, default: -> { ProspectAiClient.new }

  def perform(lead)
    return unless ProspectAiClient.configured?
    return if lead.ai_analyses.where(provider: "prospect_ai:job").pending.exists?

    raw = client_builder.call.analyze(lead)
    output = LeadAnalysisImport.new(raw.to_json).call
    lead.ai_analyses.create!(kind: "scoring_proposal", provider: "prospect_ai:job",
                             engine_version: raw["engine_version"].to_s.presence || "desconocida", output: output)
  end
end
