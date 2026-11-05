# A person who reached eQuantum through a channel. Phone and email are
# encrypted deterministically so they can be matched by equality without being
# stored in clear. Contacts are never merged automatically: a cross-channel
# coincidence becomes a ContactMatch that a person resolves.
class Contact < ApplicationRecord
  include Auditable

  encrypts :phone_e164, deterministic: true
  encrypts :email, deterministic: true, downcase: true

  belongs_to :company, optional: true
  belongs_to :primary_contact, class_name: "Contact", optional: true
  has_many :external_identities, dependent: :restrict_with_error
  has_many :conversations, dependent: :restrict_with_error
  has_many :lead_form_submissions, dependent: :restrict_with_error
  has_many :inbox_items, dependent: :restrict_with_error
  has_many :leads, dependent: :restrict_with_error

  normalizes :phone_e164, with: ->(value) { value.to_s.gsub(/[^\d+]/, "").presence }

  validates :name, length: { maximum: 160 }
  validates :phone_e164, format: { with: /\A\+[1-9]\d{6,14}\z/ }, allow_nil: true
  validate :primary_contact_is_not_self

  def masked_phone
    return if phone_e164.blank?

    "#{phone_e164[0, 4]}#{'*' * [ phone_e164.length - 6, 0 ].max}#{phone_e164[-2..]}"
  end

  private
    def primary_contact_is_not_self
      errors.add(:primary_contact, "no puede ser el mismo contacto") if primary_contact_id.present? && primary_contact_id == id
    end
end
