class ActivitiesController < ApplicationController
  def index
    authorize Activity
    scope = Activity.includes(:subject, :owner).where(owner: current_user)
    @overdue = scope.overdue.chronological
    @today = scope.due_today.chronological
    @upcoming = scope.upcoming.chronological.limit(50)
    @completed = scope.where.not(completed_at: nil).order(completed_at: :desc).limit(20)
  end

  def create
    subject = find_subject
    @activity = subject.activities.new(activity_params.merge(owner: current_user))
    authorize @activity
    if @activity.save
      redirect_back_or_to subject, notice: "Actividad registrada."
    else
      redirect_back_or_to subject, alert: @activity.errors.full_messages.to_sentence
    end
  end

  def complete
    @activity = Activity.find(params[:id])
    authorize @activity
    @activity.complete!
    redirect_back_or_to activities_path, notice: "Actividad completada."
  end

  def destroy
    @activity = Activity.find(params[:id])
    authorize @activity
    @activity.destroy!
    redirect_back_or_to activities_path, notice: "Actividad eliminada.", status: :see_other
  end

  private
    def find_subject
      type = params.dig(:activity, :subject_type)
      raise ActiveRecord::RecordNotFound unless Activity::SUBJECT_TYPES.include?(type)

      type.constantize.find(params.dig(:activity, :subject_id))
    end

    def activity_params
      params.expect(activity: [ :kind, :title, :body, :due_at, :outcome ])
    end
end
