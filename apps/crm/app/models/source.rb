class Source < ApplicationRecord
  has_many :leads, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
