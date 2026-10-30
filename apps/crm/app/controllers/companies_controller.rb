class CompaniesController < ApplicationController
  before_action :set_company, only: %i[show edit update destroy]

  def index
    authorize Company
    @query = params[:q]
    @companies = Company.search(@query).includes(:country, :owner).ordered.limit(200)
  end

  def show
    authorize @company
    @opportunities = @company.opportunities.includes(:pipeline_stage, :owner)
    @leads = @company.leads.recent
    @activities = @company.activities.includes(:owner).chronological
  end

  def new
    @company = Company.new
    authorize @company
  end

  def create
    @company = Company.new(company_params.merge(owner: current_user))
    authorize @company
    if @company.save
      redirect_to @company, notice: "Empresa creada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @company
  end

  def update
    authorize @company
    if @company.update(company_params)
      redirect_to @company, notice: "Empresa actualizada."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @company
    if @company.destroy
      redirect_to companies_path, notice: "Empresa eliminada.", status: :see_other
    else
      redirect_to @company, alert: "No se puede eliminar: tiene prospectos u oportunidades asociadas."
    end
  end

  private
    def set_company
      @company = Company.find(params[:id])
    end

    def company_params
      params.expect(company: [ :trade_name, :legal_name, :sector, :country_id, :website, :owner_id, :notes, { service_ids: [] } ])
    end
end
