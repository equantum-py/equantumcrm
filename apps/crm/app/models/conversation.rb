# One conversation per external identity, kept forever and reopened when a new
# message arrives after it was closed (plan r2, P1).
class Conversation < ApplicationRecord
  STATUSES = %w[open closed].freeze

  belongs_to :channel
  belongs_to :external_identity
  belongs_to :contact
  has_many :messages, dependent: :restrict_with_error
  has_one :inbox_item, as: :subject, dependent: :restrict_with_error

  validates :status, inclusion: { in: STATUSES }
  validates :external_identity_id, uniqueness: true
end
