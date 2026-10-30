class OpportunityService < ApplicationRecord
  belongs_to :opportunity
  belongs_to :service

  validates :service_id, uniqueness: { scope: :opportunity_id }
end
