# The id a channel uses for a person (WhatsApp wa_id, Instagram IGSID). Unique
# per channel: the same id always resolves to the same contact.
class ExternalIdentity < ApplicationRecord
  belongs_to :channel
  belongs_to :contact
  has_one :conversation, dependent: :restrict_with_error

  validates :external_id, presence: true, length: { maximum: 120 }
  validates :first_seen_at, :last_seen_at, presence: true
end
