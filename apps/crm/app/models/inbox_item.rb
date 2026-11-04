# The human work layer over a conversation or a form submission: attention
# state and supervised assignment live here, separate from the channel state
# and from the commercial state of leads and opportunities (plan r2, section 6).
class InboxItem < ApplicationRecord
  include Auditable

  KINDS = %w[conversation form_submission].freeze
  SUBJECT_TYPES = { "conversation" => "Conversation", "form_submission" => "LeadFormSubmission" }.freeze
  ATTENTION_STATUSES = %w[new in_progress waiting_customer resolved discarded].freeze
  ASSIGNMENT_STATUSES = %w[unassigned proposed confirmed].freeze
  PROPOSAL_SOURCES = %w[rule manager].freeze
  DISCARD_REASONS = %w[spam no_interest duplicate out_of_scope other].freeze

  encrypts :preview

  belongs_to :subject, polymorphic: true
  belongs_to :channel
  belongs_to :contact, optional: true
  belongs_to :lead, optional: true
  belongs_to :proposed_owner, class_name: "User", optional: true
  belongs_to :proposed_by, class_name: "User", optional: true
  belongs_to :confirmed_owner, class_name: "User", optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true
  has_many :inbox_notes, dependent: :restrict_with_error
  has_many :assignments, dependent: :restrict_with_error
  has_many :activities, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :attention_status, inclusion: { in: ATTENTION_STATUSES }
  validates :assignment_status, inclusion: { in: ASSIGNMENT_STATUSES }
  validates :proposal_source, inclusion: { in: PROPOSAL_SOURCES }, allow_nil: true
  validates :discard_reason, inclusion: { in: DISCARD_REASONS }, allow_nil: true
  validates :discard_reason, presence: true, if: -> { attention_status == "discarded" }
  validates :review_at, presence: true, if: -> { attention_status == "waiting_customer" }
  validates :proposed_owner, presence: true, if: -> { assignment_status == "proposed" }
  validates :confirmed_owner, presence: true, if: -> { assignment_status == "confirmed" }
  validates :last_activity_at, presence: true
  validates :preview, length: { maximum: 120 }
  validate :subject_matches_kind

  private
    def subject_matches_kind
      expected = SUBJECT_TYPES[kind]
      errors.add(:subject, "no corresponde al tipo de ítem") if expected && subject_type.present? && subject_type != expected
    end
end
