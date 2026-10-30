class OpportunitiesController < ApplicationController
  before_action :set_opportunity, only: %i[show edit update destroy move]

  def index
    authorize Opportunity
    @view = params[:view] == "table" ? "table" : "kanban"
    @filters = params.permit(:q, :owner_id, :country_id, :service_id)
    @stages = PipelineStage.ordered
    @opportunities = Opportunity.filter(@filters).includes(:company, :owner, :pipeline_stage, :services).order(stage_changed_at: :desc)
  end

  def show
    authorize @opportunity
    @activities = @opportunity.activities.includes(:owner).chronological
    @rates = @opportunity.services.map { |service| [ service, ServiceRate.current_for(service, @opportunity.country) ] }
  end

  def new
    @opportunity = Opportunity.new(company_id: params[:company_id], owner: current_user, pipeline_stage: PipelineStage.ordered.first)
    authorize @opportunity
  end

  def create
    @opportunity = Opportunity.new(opportunity_params)
    @opportunity.owner ||= current_user
    authorize @opportunity
    if @opportunity.save
      redirect_to @opportunity, notice: "Oportunidad creada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @opportunity
  end

  def update
    authorize @opportunity
    if @opportunity.update(opportunity_params)
      redirect_to @opportunity, notice: "Oportunidad actualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @opportunity
    @opportunity.destroy!
    redirect_to opportunities_path, notice: "Oportunidad eliminada.", status: :see_other
  end

  # Stage change from the Kanban board (drag and drop) or the stage selector.
  def move
    authorize @opportunity, :move?
    stage = PipelineStage.find(params[:pipeline_stage_id])
    if stage.lost? && params[:lost_reason].blank?
      respond_to do |format|
        format.html { redirect_to @opportunity, alert: "Para marcar como perdida indicá el motivo." }
        format.json { render json: { error: "lost_reason_required" }, status: :unprocessable_content }
      end
      return
    end

    @opportunity.update!(pipeline_stage: stage, lost_reason: params[:lost_reason].presence)
    @opportunity.activities.create!(kind: "note", owner: current_user, title: "Etapa cambiada a #{stage.name}", completed_at: Time.current)
    respond_to do |format|
      format.html { redirect_back_or_to @opportunity, notice: "Etapa actualizada a #{stage.name}." }
      format.json { render json: { id: @opportunity.id, stage: stage.name } }
    end
  end

  private
    def set_opportunity
      @opportunity = Opportunity.find(params[:id])
    end

    def opportunity_params
      permitted = params.expect(opportunity: [ :name, :company_id, :pipeline_stage_id, :owner_id, :country_id, :currency,
                                               :estimated_value, :expected_close_on, :lost_reason, { service_ids: [] } ])
      permitted.delete(:owner_id) unless current_user.can?(:"pipeline.manage_all")
      # currency must be assigned before the value so minor units are computed correctly
      permitted.to_h.sort_by { |key, _| key == "estimated_value" ? 1 : 0 }.to_h
    end
end
