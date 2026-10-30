class LeadsController < ApplicationController
  before_action :set_lead, only: %i[show edit update destroy verify discard qualify convert]

  def index
    authorize Lead
    @filters = params.permit(:q, :status, :country_id, :source_id, :service_id, :owner_id, :band)
    @leads = Lead.filter(@filters).includes(:source, :country, :services, :owner)
      .order(Arel.sql("leads.score DESC NULLS LAST"), detected_at: :desc).limit(200)
  end

  def show
    authorize @lead
    @criteria = ScoringCriterion.current
    @scores = @lead.lead_scores.index_by(&:scoring_criterion_id)
    @pending_analysis = @lead.ai_analyses.pending.order(created_at: :desc).first
    @activities = @lead.activities.includes(:owner).chronological
    @duplicates = possible_duplicates
  end

  def new
    @lead = Lead.new(source: Source.find_by(key: params[:source]), detected_at: Time.current)
    authorize @lead
  end

  def create
    @lead = Lead.new(lead_params.merge(owner: current_user))
    authorize @lead
    @analysis_text = params.dig(:lead, :analysis).to_s

    if (existing = duplicate_for(@lead))
      redirect_to existing, alert: "Ese enlace ya está registrado. Te llevamos al prospecto existente." and return
    end

    analysis_output = parse_analysis
    if analysis_output == :invalid
      render :new, status: :unprocessable_content and return
    end

    Lead.transaction do
      @lead.save!
      add_evidence(@lead)
      if analysis_output
        @lead.ai_analyses.create!(kind: "scoring_proposal", provider: "skill:claude", engine_version: "skills-v1", output: analysis_output)
      end
    end
    AnalyzeLeadJob.perform_later(@lead) if analysis_output.nil? && ProspectAiClient.configured?
    redirect_to @lead, notice: analysis_output ? "Prospecto registrado. Revisá el análisis propuesto." : "Prospecto registrado."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit
    authorize @lead
  end

  def update
    authorize @lead
    if @lead.update(lead_params)
      redirect_to @lead, notice: "Prospecto actualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @lead
    if @lead.destroy
      redirect_to leads_path, notice: "Prospecto eliminado.", status: :see_other
    else
      redirect_to @lead, alert: @lead.errors.full_messages.to_sentence
    end
  end

  def verify
    authorize @lead, :update?
    status = params[:result] == "unreachable" ? "unreachable" : "verified"
    @lead.update!(verification_status: status, status: @lead.status == "new" ? "researching" : @lead.status)
    redirect_to @lead, notice: status == "verified" ? "Fuente marcada como verificada." : "Fuente marcada como inaccesible."
  end

  def discard
    authorize @lead, :update?
    if @lead.update(status: "discarded", discard_reason: params[:discard_reason])
      redirect_to @lead, notice: "Prospecto descartado."
    else
      redirect_to @lead, alert: "Indicá el motivo del descarte."
    end
  end

  def qualify
    authorize @lead, :update?
    if @lead.update(status: "qualified")
      redirect_to @lead, notice: "Prospecto calificado."
    else
      redirect_to @lead, alert: @lead.errors.full_messages.to_sentence
    end
  end

  def convert
    authorize @lead, :convert?
    unless @lead.convertible?
      redirect_to @lead, alert: "Solo se convierten prospectos calificados y sin oportunidad." and return
    end

    opportunity = LeadConversion.new(@lead, current_user, company_name: params[:company_name]).call
    redirect_to opportunity, notice: "Oportunidad creada en el pipeline."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @lead, alert: e.record.errors.full_messages.to_sentence
  end

  private
    def set_lead
      @lead = Lead.find(params[:id])
    end

    def lead_params
      params.expect(lead: [ :title, :need_summary, :original_url, :author_display_name, :published_at, :detected_at,
                            :published_budget_text, :urgency, :source_id, :country_id, :company_id, :owner_id,
                            :recommended_action, :suggested_message, { service_ids: [] } ])
    end

    def duplicate_for(lead)
      return if lead.source.nil?

      Lead.find_by(fingerprint: Lead.fingerprint_for(source_key: lead.source.key, url: lead.original_url, text: lead.need_summary.presence || lead.title))
    end

    def parse_analysis
      return nil if @analysis_text.blank?

      LeadAnalysisImport.new(@analysis_text).call
    rescue LeadAnalysisImport::Invalid => e
      @lead.errors.add(:base, e.message)
      :invalid
    end

    def add_evidence(lead)
      excerpt = params.dig(:lead, :evidence_excerpt).presence || lead.need_summary
      return if excerpt.blank?

      lead.lead_evidences.create!(kind: "post_excerpt", url: lead.original_url, excerpt: excerpt.to_s.first(2000),
                                  captured_at: Time.current, captured_by: current_user)
    end

    def possible_duplicates
      return Lead.none if @lead.author_display_name.blank?

      Lead.where.not(id: @lead.id).where(author_display_name: @lead.author_display_name, source_id: @lead.source_id).limit(5)
    end
end
