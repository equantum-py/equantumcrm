# Turns a qualified lead into an opportunity in the first open stage after "Calificado".
class LeadConversion
  def initialize(lead, user, company_name: nil)
    @lead = lead
    @user = user
    @company_name = company_name
  end

  def call
    Lead.transaction do
      company = @lead.company || Company.create!(trade_name: @company_name.presence || @lead.author_display_name.presence || @lead.title.first(80),
                                                 country: @lead.country, owner: @user)
      opportunity = Opportunity.create!(
        name: @lead.title, company: company, lead: @lead, owner: @lead.owner || @user, country: @lead.country,
        pipeline_stage: PipelineStage.find_by(name: "Pendiente de contacto") || PipelineStage.ordered.first,
        currency: @lead.country&.default_currency, services: @lead.services
      )
      @lead.update!(status: "converted", company: company)
      opportunity
    end
  end
end
