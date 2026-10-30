class LeadAnalysesController < ApplicationController
  before_action :set_lead

  def create
    authorize @lead, :review_analysis?
    output = LeadAnalysisImport.new(params[:analysis]).call
    @lead.ai_analyses.create!(kind: "scoring_proposal", provider: "skill:claude", engine_version: "skills-v1", output: output)
    redirect_to @lead, notice: "Análisis cargado. Revisalo antes de aceptarlo."
  rescue LeadAnalysisImport::Invalid => e
    redirect_to @lead, alert: e.message
  end

  def accept
    authorize @lead, :review_analysis?
    analysis = @lead.ai_analyses.pending.find(params[:id])
    LeadAnalysisAcceptance.new(analysis, current_user).call
    redirect_to @lead, notice: "Análisis aceptado y puntuación recalculada."
  end

  def reject
    authorize @lead, :review_analysis?
    analysis = @lead.ai_analyses.pending.find(params[:id])
    analysis.update!(status: "rejected", reviewed_by: current_user, reviewed_at: Time.current)
    redirect_to @lead, notice: "Análisis rechazado."
  end

  private
    def set_lead
      @lead = Lead.find(params[:lead_id])
    end
end
