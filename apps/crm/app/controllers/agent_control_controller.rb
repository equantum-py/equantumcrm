# Agent Control: which agents exist, what they may do, what they did and what
# waits for a person. Read-only in this delivery.
class AgentControlController < ApplicationController
  def show
    authorize :agent_control
    @agents = Agent.ordered.to_a
    @last_runs = AgentRun.where(id: AgentRun.select("DISTINCT ON (agent_id) id").order(:agent_id, started_at: :desc)).index_by(&:agent_id)
    @runs = AgentRun.recent.includes(:agent, :triggered_by).limit(25)
    @failed_last_7_days = AgentRun.failed.where(started_at: 7.days.ago..).count
    @pending_analyses = AiAnalysis.pending.where(subject_type: "Lead").order(created_at: :desc)
    @pending_preview = @pending_analyses.includes(:subject).limit(8)
    @unverified_from_agents = Lead.where(created_via: %w[api skill], verification_status: "unverified").where.not(status: %w[discarded converted]).count
  end
end
