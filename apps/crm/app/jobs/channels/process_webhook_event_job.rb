# Processes one stored webhook event (plan r2, 2.2). Jobs for the same sender
# run one at a time; failures retry with growing waits and, after the last
# attempt, the event is left as "failed" for manual reprocessing. Effects are
# keyed by unique ids, so a retry never duplicates them.
module Channels
  class ProcessWebhookEventJob < ApplicationJob
    queue_as :inbound

    limits_concurrency to: 1, key: ->(event) { event.concurrency_key }, duration: 5.minutes

    retry_on StandardError, attempts: WebhookEvent::MAX_ATTEMPTS, wait: :polynomially_longer do |job, error|
      job.arguments.first.mark_failed!(error)
    end

    def perform(event)
      event.reload
      return unless event.pending?

      processor = Processors.for(event)
      return if processor.nil? # Stored and waiting: no processor for this type yet.

      begin
        processor.call(event)
      rescue StandardError => error
        event.record_attempt!(error)
        raise
      end
      event.mark_processed!
    end
  end
end
