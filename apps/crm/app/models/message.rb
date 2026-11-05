# An inbound message. Phase 1 stores inbound only; the database rejects any
# other direction (messages_inbound_only).
class Message < ApplicationRecord
  DIRECTIONS = %w[in].freeze
  CONTENT_STATUSES = %w[ok unsupported unavailable].freeze
  KINDS = %w[text image audio video document sticker location contacts interactive button reaction other].freeze

  encrypts :body

  belongs_to :conversation
  belongs_to :webhook_event, optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :content_status, inclusion: { in: CONTENT_STATUSES }
  validates :message_kind, inclusion: { in: KINDS }
  validates :external_message_id, presence: true, length: { maximum: 200 }
  validates :sent_at, :received_at, presence: true

  scope :chronological, -> { order(:sent_at, :id) }
end
