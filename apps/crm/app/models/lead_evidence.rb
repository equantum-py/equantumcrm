class LeadEvidence < ApplicationRecord
  KINDS = %w[post_excerpt page_snapshot note].freeze

  belongs_to :lead
  belongs_to :captured_by, class_name: "User", optional: true

  before_validation { self.content_sha256 = Digest::SHA256.hexdigest(excerpt.to_s) if excerpt.present? }

  validates :kind, inclusion: { in: KINDS }
  validates :excerpt, length: { maximum: 2000 }
  validates :captured_at, presence: true
end
