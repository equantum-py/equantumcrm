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
    assert_match "ArgumentError: fallo sintético", event.last_error
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
end
