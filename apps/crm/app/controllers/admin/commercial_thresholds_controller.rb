class Admin::CommercialThresholdsController < ApplicationController
  before_action :set_threshold, only: %i[edit update destroy]

  def index
    authorize CommercialThreshold
    @thresholds = CommercialThreshold.includes(:approved_by).order(:currency)
    @rubrics = RubricVersion.includes(:approved_by).order(:version)
  end

  def new
    @threshold = CommercialThreshold.new
    authorize @threshold
  end

  def create
    @threshold = CommercialThreshold.new(approved_by: current_user, approved_at: Time.current)
    @threshold.assign_attributes(threshold_params)
    authorize @threshold
    if @threshold.save
      redirect_to admin_commercial_thresholds_path, notice: "Umbral aprobado y registrado."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @threshold
  end

  def update
    authorize @threshold
    @threshold.assign_attributes(threshold_params.merge(approved_by: current_user, approved_at: Time.current))
    if @threshold.save
      redirect_to admin_commercial_thresholds_path, notice: "Umbral actualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @threshold
    @threshold.destroy!
    redirect_to admin_commercial_thresholds_path, notice: "Umbral eliminado.", status: :see_other
  end

  private
    def set_threshold
      @threshold = CommercialThreshold.find(params[:id])
    end

    # currency first so the amounts are converted with the right number of decimals
    def threshold_params
      permitted = params.expect(commercial_threshold: [ :currency, :min_viable_amount, :high_value_amount, :notes ])
      permitted.to_h.sort_by { |key, _| key.end_with?("_amount") ? 1 : 0 }.to_h
    end
end
