# A Meta Lead Ads form submission. The webhook only carries its id; the answers
# are retrieved afterwards, so the retrieval state is explicit and visible.
class LeadFormSubmission < ApplicationRecord
  include Auditable

  RETRIEVAL_STATUSES = %w[pending retrieved failed].freeze

  encrypts :field_data

  belongs_to :channel
  belongs_to :contact, optional: true
  belongs_to :lead, optional: true
  belongs_to :webhook_event, optional: true
  has_one :inbox_item, as: :subject, dependent: :restrict_with_error

  validates :leadgen_id, presence: true, uniqueness: true, length: { maximum: 64 }
  validates :retrieval_status, inclusion: { in: RETRIEVAL_STATUSES }
  validates :received_at, presence: true

  def answers
    field_data.present? ? JSON.parse(field_data) : []
  end

  def answers=(value)
    self.field_data = value.nil? ? nil : JSON.generate(value)
  end
end
