class Activity < ApplicationRecord
  include Auditable

  KINDS = %w[call meeting task follow_up reminder note].freeze
  SUBJECT_TYPES = %w[Lead Opportunity Company].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :owner, class_name: "User"
  belongs_to :inbox_item, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :title, presence: true, length: { maximum: 200 }

  scope :pending, -> { where(completed_at: nil) }
  # Activities on test or demo leads, or on opportunities born from them.
  # Company activities are always real: companies have no test marker.
  scope :test_data, lambda {
    where(subject_type: "Lead", subject_id: Lead.test_data.select(:id))
      .or(where(subject_type: "Opportunity", subject_id: Opportunity.test_data.select(:id)))
  }
  scope :real, -> { where.not(id: test_data.select(:id)) }
  scope :overdue, -> { pending.where(due_at: ...Time.current) }
  scope :due_today, -> { pending.where(due_at: Time.current..Time.current.end_of_day) }
  scope :upcoming, -> { pending.where(due_at: Time.current.end_of_day..).or(pending.where(due_at: nil)) }
  scope :chronological, -> { order(Arel.sql("due_at IS NULL, due_at ASC"), created_at: :desc) }

  def completed? = completed_at.present?
  def overdue? = !completed? && due_at.present? && due_at < Time.current

  def complete!
    update!(completed_at: Time.current)
  end
end
