class CompanyService < ApplicationRecord
  belongs_to :company
  belongs_to :service

  validates :service_id, uniqueness: { scope: :company_id }
end
