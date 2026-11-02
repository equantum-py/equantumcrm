# One execution of an agent: who, when, how long, which source, what it found,
# duplicates, errors and how many results wait for a person to approve them.
class AgentRun < ApplicationRecord
  STATUSES = %w[running succeeded failed skipped].freeze
  TRIGGERS = %w[manual scheduled event api].freeze

  belongs_to :agent
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :triggered_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :started_at, presence: true
  validates :leads_detected, :duplicates, :errors_count, :pending_approvals, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :recent, -> { order(started_at: :desc) }
  scope :failed, -> { where(status: "failed") }

  # Runs the block and records the outcome. The block receives the run so it
  # can add counts; an exception marks the run as failed and is re-raised.
  def self.track(agent, trigger:, subject: nil, source_key: nil, source_url: nil, triggered_by: nil)
    run = create!(agent: agent, trigger: trigger, subject: subject, source_key: source_key, source_url: source_url,
                  triggered_by: triggered_by, started_at: Time.current, status: "running")
    result = yield run
    run.update!(status: run.status == "running" ? "succeeded" : run.status, finished_at: Time.current)
    result
  rescue StandardError => e
    run&.update_columns(status: "failed", finished_at: Time.current, errors_count: run.errors_count + 1,
                        error_messages: run.error_messages + [ "#{e.class}: #{e.message}".truncate(300) ], updated_at: Time.current)
    raise
  end

  def duration
    return unless finished_at

    finished_at - started_at
  end
end
