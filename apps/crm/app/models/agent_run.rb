# One execution of an agent: who, when, how long, which source, what it found,
# duplicates, errors and how many results wait for a person to approve them.
class AgentRun < ApplicationRecord
  STATUSES = %w[running succeeded failed skipped].freeze
  TRIGGERS = %w[manual scheduled event api].freeze
  MAX_ERROR_LENGTH = 300
  MAX_STORED_ERRORS = 20
  FILTERED = "[FILTRADO]".freeze

  # Raised when the run record itself cannot be closed. The agent's work may
  # have finished, so this is reported instead of being swallowed.
  class TrackingError < StandardError; end

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
  # can add counts.
  # - If the run cannot be created, the work does not start (fail closed).
  # - If the work raises, the run is marked failed and the ORIGINAL error is
  #   re-raised, even if marking the run fails too (that is reported).
  # - If the work succeeds but the run cannot be closed, TrackingError is raised.
  def self.track(agent, trigger:, subject: nil, source_key: nil, source_url: nil, triggered_by: nil)
    run = create!(agent: agent, trigger: trigger, subject: subject, source_key: source_key,
                  source_url: sanitize_url(source_url), triggered_by: triggered_by, started_at: Time.current, status: "running")
    begin
      result = yield run
    rescue StandardError => e
      run.record_failure(e)
      raise e
    end
    run.finish!
    result
  end

  # Removes secrets and personal data from an error before it is stored or
  # shown: bearer tokens, credentials in URLs, key=value secrets, API tokens,
  # e-mail addresses and the values of secret environment variables.
  def self.sanitize_error(error)
    text = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
    sanitize_text(text).truncate(MAX_ERROR_LENGTH)
  end

  def self.sanitize_text(text)
    text = text.to_s.dup
    secret_env_values.each { |value| text.gsub!(value, FILTERED) }
    text.gsub!(/\b(Bearer|Basic|Token)\s+[A-Za-z0-9._~+\/=-]+/i, "\\1 #{FILTERED}")
    text.gsub!(%r{(\w+://)[^/\s:@]+:[^/\s@]+@}, "\\1#{FILTERED}@")
    text.gsub!(/\b((?:api[_-]?key|access[_-]?token|token|secret|password|passwd|pwd|authorization|signature|sig|key)\s*[=:]\s*["']?)[^\s&"',;]+/i,
               "\\1#{FILTERED}")
    text.gsub!(/\b#{Regexp.escape(ApiClient::TOKEN_PREFIX)}[A-Za-z0-9]+/, FILTERED)
    text.gsub!(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/, "[EMAIL]")
    text.gsub!(/\b[A-Za-z0-9_-]{40,}\b/, FILTERED)
    text
  end

  def self.sanitize_url(url)
    return if url.blank?

    sanitize_text(url).truncate(500)
  end

  def self.secret_env_values
    ENV.select { |name, value| name.match?(/TOKEN|SECRET|PASSWORD|API_KEY|PRIVATE_KEY|MASTER_KEY/) && value.to_s.length >= 8 }.values
  end

  def record_failure(error)
    update_columns(status: "failed", finished_at: Time.current, errors_count: errors_count + 1,
                   error_messages: (error_messages + [ self.class.sanitize_error(error) ]).last(MAX_STORED_ERRORS), updated_at: Time.current)
  rescue StandardError => tracking_error
    report_tracking_problem(tracking_error, while_handling: error)
  end

  # Adds a non-fatal error (e.g. one item of a batch could not be read).
  def add_error(error)
    self.errors_count += 1
    self.error_messages = (error_messages + [ self.class.sanitize_error(error) ]).last(MAX_STORED_ERRORS)
  end

  def finish!
    update!(status: status == "running" ? "succeeded" : status, finished_at: Time.current)
  rescue StandardError => e
    report_tracking_problem(e)
    raise TrackingError, "No se pudo cerrar la ejecución #{id} del agente #{agent&.key}: #{self.class.sanitize_error(e)}"
  end

  def duration
    return unless finished_at

    finished_at - started_at
  end

  private
    def report_tracking_problem(error, while_handling: nil)
      context = { agent_run_id: id, agent: agent&.key, original_error: while_handling && self.class.sanitize_error(while_handling) }
      Rails.logger.error("[AgentRun] #{self.class.sanitize_error(error)} #{context.compact}")
      Rails.error.report(error, handled: true, context: context.compact)
    end
end
