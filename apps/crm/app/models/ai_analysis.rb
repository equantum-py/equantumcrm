# A machine-generated proposal (from Prospect AI or a Claude Skill). It never
# changes business records by itself: a user must accept it.
class AiAnalysis < ApplicationRecord
  STATUSES = %w[pending_review accepted rejected superseded].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :kind, :provider, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending_review") }

  def criteria = Array(output["criteria"])
  def service_keys = Array(output["services"])
end
