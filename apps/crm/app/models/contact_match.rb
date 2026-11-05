# A possible link between two contacts from different channels. Only a person
# accepts it; accepting is reversible (contacts.primary_contact_id).
class ContactMatch < ApplicationRecord
  include Auditable

  REASONS = %w[same_phone same_email].freeze
  STATUSES = %w[pending accepted rejected reverted].freeze

  belongs_to :contact
  belongs_to :candidate_contact, class_name: "Contact"
  belongs_to :decided_by, class_name: "User", optional: true

  validates :reason, inclusion: { in: REASONS }
  validates :status, inclusion: { in: STATUSES }
  validate :distinct_contacts

  scope :pending, -> { where(status: "pending") }

  private
    def distinct_contacts
      errors.add(:candidate_contact, "debe ser otro contacto") if contact_id.present? && contact_id == candidate_contact_id
    end
end
