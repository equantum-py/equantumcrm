require "test_helper"

# PR-1: the processing job and the sweeper (plan r2, 2.1, 7.4 and S12). PR-1
# registers no processors, so these tests register a synthetic one.
class ChannelsWebhookJobsTest < ActiveJob::TestCase
  include MetaWebhookHelper

  class RecordingProcessor
    attr_reader :calls

    def initialize(fail_times: 0)
      @fail_times = fail_times
      @calls = 0
    end

    def call(_event)
      @calls += 1
      raise ArgumentError, "fallo sintético" if @calls <= @fail_times
    end
  end

  # Raises exceptions whose messages carry synthetic personal data, as a real
  # processor might when it echoes a payload value (PR #12 privacy fix).
  class LeakyProcessor
    attr_reader :calls

    def initialize(error_factory, fail_times: 99)
      @error_factory = error_factory
      @fail_times = fail_times
      @calls = 0
    end

    def call(_event)
      @calls += 1
      raise @error_factory.call if @calls <= @fail_times
    end
  end

  SENSITIVE = {
    phone: "+595981777888",
    wa_id: "595981777888",
    email: "persona.sintetica@e2e.invalid",
    text: "Mensaje privado sintético: mi tarjeta termina en 4242"
  }.freeze

  def sensitive_message
    "Fallo con #{SENSITIVE[:phone]} (#{SENSITIVE[:wa_id]}), #{SENSITIVE[:email]} y \"#{SENSITIVE[:text]}\""
  end

  def assert_no_sensitive_data(text, where)
    SENSITIVE.each_value { |value| assert_not_includes text.to_s, value, "#{where} contiene un dato sensible" }
  end

  def log_since(offset)
    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    log = Rails.root.join("log/test.log")
    File.exist?(log) ? File.binread(log, nil, offset).force_encoding("UTF-8").scrub : ""
  end

  def log_offset
    log = Rails.root.join("log/test.log")
    File.exist?(log) ? File.size(log) : 0
  end

  teardown { Channels::Processors.unregister("whatsapp_business_account") }

  def store_event(received_at: Time.current)
    Meta::EventRecorder.new(whatsapp_body, received_at: received_at).fragments.first.then do |fragment|
      WebhookEvent.create!(provider: "meta", object_type: fragment.object_type, event_key: fragment.event_key,
                           payload: JSON.generate(fragment.payload), summary: fragment.summary, received_at: received_at)
    end
  end

  test "without a processor the event stays pending and untouched" do
    event = store_event
    Channels::ProcessWebhookEventJob.perform_now(event)
    event.reload
    assert_equal "pending", event.status
    assert_equal 0, event.attempts
  end

  test "a registered processor marks the event processed once" do
    processor = RecordingProcessor.new
    Channels::Processors.register("whatsapp_business_account", processor)
    event = store_event
    Channels::ProcessWebhookEventJob.perform_now(event)
    Channels::ProcessWebhookEventJob.perform_now(event)
    assert_equal "processed", event.reload.status
    assert_equal 1, processor.calls
  end

  test "failures retry and the event is failed after the last attempt" do
    processor = RecordingProcessor.new(fail_times: 99)
    Channels::Processors.register("whatsapp_business_account", processor)
    event = store_event
    perform_enqueued_jobs { Channels::ProcessWebhookEventJob.perform_later(event) }
    event.reload
    assert_equal "failed", event.status
    assert_equal WebhookEvent::MAX_ATTEMPTS, event.attempts
    assert_equal WebhookEvent::MAX_ATTEMPTS, processor.calls
    assert_equal "unexpected_error:ArgumentError", event.last_error
  end

  test "a transient failure retries and then processes" do
    processor = RecordingProcessor.new(fail_times: 2)
    Channels::Processors.register("whatsapp_business_account", processor)
    event = store_event
    perform_enqueued_jobs { Channels::ProcessWebhookEventJob.perform_later(event) }
    event.reload
    assert_equal "processed", event.status
    assert_equal 2, event.attempts
    assert_nil event.last_error
  end

  # S12: an event stored but never enqueued (restart in between) is swept once.
  test "the sweeper re-enqueues stale pending events once per window" do
    Channels::Processors.register("whatsapp_business_account", RecordingProcessor.new)
    stale = store_event(received_at: 10.minutes.ago)
    fresh = store_event(received_at: 1.minute.ago)
    assert_enqueued_with(job: Channels::ProcessWebhookEventJob, args: [ stale ]) do
      assert_equal 1, Channels::SweepPendingEventsJob.perform_now
    end
    assert_equal 0, Channels::SweepPendingEventsJob.perform_now
    assert_not_nil stale.reload.last_enqueued_at
    assert_nil fresh.reload.last_enqueued_at
  end

  test "the sweeper ignores types without a processor" do
    store_event(received_at: 10.minutes.ago)
    assert_no_enqueued_jobs { assert_equal 0, Channels::SweepPendingEventsJob.perform_now }
  end

  test "jobs for the same sender share a concurrency key" do
    first = store_event
    second = store_event
    assert_equal first.concurrency_key, second.concurrency_key
    assert_not_includes first.concurrency_key, "595981000111"
  end

  # Privacy: no exception text reaches the database, the audit log or the log,
  # neither during retries nor after the final failure.
  test "exceptions with personal data never reach last_error, the audit log or the log" do
    errors = {
      "ArgumentError" => -> { ArgumentError.new(sensitive_message) },
      "RuntimeError" => -> { RuntimeError.new(sensitive_message) },
      "KeyError" => -> { KeyError.new(sensitive_message) },
      "JSON::ParserError" => -> { JSON::ParserError.new(sensitive_message) },
      "ActiveRecord::RecordInvalid" => lambda {
        record = Contact.new(phone_e164: "123")
        record.errors.add(:phone_e164, sensitive_message)
        ActiveRecord::RecordInvalid.new(record)
      }
    }
    errors.each do |class_name, factory|
      processor = LeakyProcessor.new(factory)
      Channels::Processors.register("whatsapp_business_account", processor)
      event = store_event
      offset = log_offset
      last_audit_id = AuditLog.maximum(:id).to_i

      perform_enqueued_jobs { Channels::ProcessWebhookEventJob.perform_later(event) }

      event.reload
      assert_equal "failed", event.status, class_name
      assert_equal WebhookEvent::MAX_ATTEMPTS, processor.calls, class_name
      assert_equal "unexpected_error:#{class_name}", event.last_error
      raw = WebhookEvent.connection.select_value("SELECT last_error FROM webhook_events WHERE id = #{event.id}")
      assert_no_sensitive_data(raw, "webhook_events.last_error (#{class_name})")
      assert_no_sensitive_data(AuditLog.where("id > ?", last_audit_id).map { |row| row.changeset.to_json }.join, "audit_logs (#{class_name})")
      log = log_since(offset)
      assert_includes log, "Channels::ProcessingError::Sanitized", "el registro de reintentos debería estar en el log"
      assert_no_sensitive_data(log, "log/test.log (#{class_name})")
    end
  end

  test "each retry stores only the code and a later success clears it" do
    processor = LeakyProcessor.new(-> { ArgumentError.new(sensitive_message) }, fail_times: 3)
    Channels::Processors.register("whatsapp_business_account", processor)
    event = store_event
    offset = log_offset
    seen = []
    original = WebhookEvent.instance_method(:record_attempt!)
    WebhookEvent.define_method(:record_attempt!) do |error|
      original.bind_call(self, error)
      seen << WebhookEvent.connection.select_value("SELECT last_error FROM webhook_events WHERE id = #{id}")
    end

    perform_enqueued_jobs { Channels::ProcessWebhookEventJob.perform_later(event) }

    assert_equal [ "unexpected_error:ArgumentError" ] * 3, seen
    event.reload
    assert_equal "processed", event.status
    assert_equal 3, event.attempts
    assert_nil event.last_error
    assert_no_sensitive_data(log_since(offset), "log/test.log")
  ensure
    WebhookEvent.define_method(:record_attempt!, original) if original
  end

  test "the job re-raises only a sanitized error without the original as cause" do
    Channels::Processors.register("whatsapp_business_account", LeakyProcessor.new(-> { RuntimeError.new(sensitive_message) }))
    event = store_event
    error = assert_raises(Channels::ProcessingError::Sanitized) { Channels::ProcessWebhookEventJob.new(event).perform(event) }
    assert_equal "unexpected_error:RuntimeError", error.message
    assert_nil error.cause
    assert_no_sensitive_data(error.full_message(highlight: false), "la excepción relanzada")
  end

  test "processors can raise only allowed codes" do
    error = Channels::ProcessingError.new("graph_token_invalid")
    assert_equal "graph_token_invalid", Channels::ProcessingError.code_for(error)
    assert_raises(ArgumentError) { Channels::ProcessingError.new(sensitive_message) }
    anonymous = Class.new(StandardError)
    assert_equal "unexpected_error", Channels::ProcessingError.code_for(anonymous.new(sensitive_message))
  end
end
