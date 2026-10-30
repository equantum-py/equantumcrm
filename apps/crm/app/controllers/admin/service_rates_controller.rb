class Admin::ServiceRatesController < ApplicationController
  before_action :set_rate, only: %i[edit update destroy]

  def index
    authorize ServiceRate
    @services = Service.active.ordered
    @rates = ServiceRate.includes(:service, :country, :approved_by).order("services.name", :valid_from).references(:service)
  end

  def new
    @rate = ServiceRate.new(valid_from: Date.current)
    authorize @rate
  end

  def create
    @rate = ServiceRate.new(approved_by: current_user, approved_at: Time.current)
    @rate.assign_attributes(rate_params)
    authorize @rate
    if @rate.save
      redirect_to admin_service_rates_path, notice: "Tarifa aprobada y registrada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @rate
  end

  def update
    authorize @rate
    @rate.assign_attributes(rate_params.merge(approved_by: current_user, approved_at: Time.current))
    if @rate.save
      redirect_to admin_service_rates_path, notice: "Tarifa actualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @rate
    @rate.destroy!
    redirect_to admin_service_rates_path, notice: "Tarifa eliminada.", status: :see_other
  end

  private
    def set_rate
      @rate = ServiceRate.find(params[:id])
    end

    # currency first so the amounts are converted with the right number of decimals
    def rate_params
      permitted = params.expect(service_rate: [ :service_id, :country_id, :currency, :unit, :min_amount, :max_amount, :valid_from, :valid_until, :notes ])
      permitted.to_h.sort_by { |key, _| key.end_with?("_amount") ? 1 : 0 }.to_h
    end
end
