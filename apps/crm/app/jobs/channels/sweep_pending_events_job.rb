# Re-enqueues events that were stored but never processed, for example when the
# server restarted between storing and enqueueing (plan r2, 2.1 and E2E-02).
# Only types with a registered processor are swept, and each event at most
# once every SWEEP_AFTER.
module Channels
  class SweepPendingEventsJob < ApplicationJob
    queue_as :inbound

    SWEEP_AFTER = 5.minutes
    BATCH = 500

    def perform
      types = Processors.registered_object_types
      return 0 if types.empty?

      cutoff = SWEEP_AFTER.ago
      events = WebhookEvent.pending.where(object_type: types)
                           .where(received_at: ...cutoff)
                           .where("last_enqueued_at IS NULL OR last_enqueued_at < ?", cutoff)
                           .where(attempts: ...WebhookEvent::MAX_ATTEMPTS)
                           .order(:received_at).limit(BATCH).to_a
      events.each do |event|
        event.update_column(:last_enqueued_at, Time.current)
        ProcessWebhookEventJob.perform_later(event)
      end
      events.size
    end
  end
end
