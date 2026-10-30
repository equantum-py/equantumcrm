class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @leads = policy(Lead).index? && @query.present? ? Lead.filter(q: @query).limit(10) : Lead.none
    @companies = policy(Company).index? && @query.present? ? Company.search(@query).limit(10) : Company.none
    @opportunities = policy(Opportunity).index? && @query.present? ? Opportunity.filter(q: @query).includes(:company).limit(10) : Opportunity.none
  end

  private
    # Each result group is filtered by its own policy above.
    def skip_authorization_check? = true
end
