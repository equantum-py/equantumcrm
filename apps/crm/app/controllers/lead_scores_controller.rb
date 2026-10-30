class LeadScoresController < ApplicationController
  before_action :set_lead

  def edit
    authorize @lead, :score?
    @criteria = ScoringCriterion.current
    @scores = @lead.lead_scores.index_by(&:scoring_criterion_id)
  end

  def update
    authorize @lead, :score?
    @criteria = ScoringCriterion.current
    Lead.transaction do
      @criteria.each do |criterion|
        attrs = params.dig(:scores, criterion.key)
        next if attrs.blank? || attrs[:points].blank?

        score = @lead.lead_scores.find_or_initialize_by(scoring_criterion: criterion)
        score.update!(points: attrs[:points], basis: attrs[:basis], justification: attrs[:justification], set_by: "human")
      end
      @lead.recalculate_score!
    end
    redirect_to @lead, notice: "Puntuación guardada."
  rescue ActiveRecord::RecordInvalid => e
    @scores = @lead.lead_scores.index_by(&:scoring_criterion_id)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_content
  end

  private
    def set_lead
      @lead = Lead.find(params[:lead_id])
    end
end
