class Service < ApplicationRecord
  has_many :service_rates, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :value_tier, inclusion: { in: %w[high medium low] }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
