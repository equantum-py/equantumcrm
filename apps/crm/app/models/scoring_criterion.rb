class ScoringCriterion < ApplicationRecord
  BANDS = { "very_high" => 80..100, "high" => 60..79, "medium" => 40..59, "low" => 0..39 }.freeze

  validates :key, presence: true, uniqueness: { scope: :version }
  validates :name, presence: true
  validates :max_points, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:position) }

  def self.current_version
    maximum(:version)
  end

  def self.current
    where(version: current_version).ordered
  end

  def self.band_for(score)
    BANDS.find { |_band, range| range.cover?(score) }&.first
  end
end
