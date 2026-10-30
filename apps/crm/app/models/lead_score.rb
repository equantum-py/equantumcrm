class LeadScore < ApplicationRecord
  BASES = %w[verified inferred].freeze

  belongs_to :lead
  belongs_to :scoring_criterion

  validates :basis, inclusion: { in: BASES }
  validates :set_by, inclusion: { in: %w[human ai_accepted] }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :scoring_criterion_id, uniqueness: { scope: :lead_id }
  validate :points_within_criterion_max

  private
    def points_within_criterion_max
      return if scoring_criterion.nil? || points.nil?

      if points > scoring_criterion.max_points
        errors.add(:points, "no puede superar #{scoring_criterion.max_points} en #{scoring_criterion.name}")
      end
    end
end
