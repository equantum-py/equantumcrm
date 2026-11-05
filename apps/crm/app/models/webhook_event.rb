# One entry of a Meta webhook delivery, stored before any processing so that a
# restart never loses an accepted event. event_key is unique: Meta retries and
# duplicate entries are ignored. The raw fragment is encrypted; summary holds
# only sanitized fields (kind, ids, times, a digest of the sender).
class WebhookEvent < ApplicationRecord
  STATUSES = %w[pending processed failed ignored].freeze
  MAX_ATTEMPTS = 5

  encrypts :payload

  belongs_to :channel, optional: true

  validates :provider, :object_type, :event_key, :received_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }

  def pending? = status == "pending"

  def payload_data
    JSON.parse(payload)
  end

  # Serializes jobs per sender so two messages from one person never race.
  def concurrency_key
    "#{channel_id || 'none'}:#{summary['sender_digest'] || event_key}"
  end

  def mark_processed!
    update!(status: "processed", processed_at: Time.current, last_error: nil)
  end

  # last_error only ever holds a system-defined code (Channels::ProcessingError),
  # never an exception message: messages can echo phone numbers, emails or
  # message text from the payload.
  def record_attempt!(error)
    update!(attempts: attempts + 1, last_error: Channels::ProcessingError.code_for(error))
  end

  def mark_failed!(error)
    update!(status: "failed", last_error: Channels::ProcessingError.code_for(error))
  end
end
