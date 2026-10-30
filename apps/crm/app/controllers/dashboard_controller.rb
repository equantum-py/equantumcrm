class DashboardController < ApplicationController
  def show
    authorize :dashboard
    @filters = filter_params
    @metrics = DashboardMetrics.new(**@filters.to_h.symbolize_keys)
  end

  private
    def filter_params
      params.permit(:from, :to, :country_id, :service_id, :source_id, :owner_id)
    end
end
