class Admin::ServiceRatesController < ApplicationController
  before_action :set_rate, only: %i[edit update destroy approve]

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
    @rate = ServiceRate.new(created_by: current_user, status: "pending")
    @rate.assign_attributes(rate_params)
    authorize @rate
    if @rate.save
      redirect_to admin_service_rates_path, notice: "Tarifa registrada. Queda pendiente de aprobación."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @rate
  end

  def update
    authorize @rate
    @rate.assign_terms(rate_params)
    if @rate.save
      notice = @rate.status == "pending" ? "Tarifa actualizada. Queda pendiente de aprobación." : "Tarifa actualizada."
      redirect_to admin_service_rates_path, notice: notice
    else
      render :edit, status: :unprocessable_content
    end
  end

  def approve
    authorize @rate
    @rate.approve!(current_user)
    redirect_to admin_service_rates_path, notice: "Tarifa aprobada."
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
