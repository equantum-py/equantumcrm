class Service < ApplicationRecord
  has_many :service_rates, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
