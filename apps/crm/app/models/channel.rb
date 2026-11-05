# An inbound Meta account (a WhatsApp number, a Facebook page for Lead Ads or
# an Instagram account). Secrets never live here: they stay in the environment.
class Channel < ApplicationRecord
  include Auditable

  KINDS = %w[whatsapp meta_lead_ads instagram].freeze
  STATUSES = %w[planned configured operational paused].freeze

  belongs_to :default_owner, class_name: "User", optional: true
  has_many :external_identities, dependent: :restrict_with_error
  has_many :conversations, dependent: :restrict_with_error
  has_many :lead_form_submissions, dependent: :restrict_with_error
  has_many :inbox_items, dependent: :restrict_with_error
  has_many :webhook_events, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :name, presence: true, length: { maximum: 120 }
  validates :external_account_id, presence: true, uniqueness: { scope: :kind }

  scope :real, -> { where(synthetic: false) }
end
