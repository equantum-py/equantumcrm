class LeadService < ApplicationRecord
  belongs_to :lead
  belongs_to :service

  validates :service_id, uniqueness: { scope: :lead_id }
end
