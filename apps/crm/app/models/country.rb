class Country < ApplicationRecord
  validates :iso2, presence: true, uniqueness: true, length: { is: 2 }
  validates :name, :default_currency, :locale, :timezone, presence: true

  scope :ordered, -> { order(target_market: :desc, name: :asc) }
end
