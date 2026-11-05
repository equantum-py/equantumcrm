# Errors raised while processing a webhook event carry only a system-defined
# code, never text that could come from a payload, a person or a third-party
# exception (plan r2, 11; PR #12 privacy fix).
module Channels
  class ProcessingError < StandardError
    # Codes processors may raise on purpose. Any other failure is reported as
    # "unexpected_error" plus the exception class name, which is defined in
    # code and never contains data.
    CODES = %w[
      payload_invalid
      channel_unknown
      graph_token_invalid
      graph_unavailable
      graph_timeout
      graph_response_invalid
    ].freeze
    UNEXPECTED = "unexpected_error".freeze
    CLASS_NAME = /\A[A-Z][A-Za-z0-9]*(::[A-Z][A-Za-z0-9]*)*\z/

    attr_reader :code

    def initialize(code)
      raise ArgumentError, "código de error no permitido" unless CODES.include?(code.to_s)

      @code = code.to_s
      super(@code)
    end

    # The only text ever stored in webhook_events.last_error or logged for a
    # processing failure.
    def self.code_for(error)
      return error.code if error.is_a?(self) || error.is_a?(Sanitized)

      name = error.class.name.to_s
      name.match?(CLASS_NAME) ? "#{UNEXPECTED}:#{name}".first(160) : UNEXPECTED
    end

    # What the job re-raises so that Active Job's retry and failure logs, the
    # queue's failed-execution records and error reporters only ever see the
    # code. It is raised without a cause, so the original message is dropped.
    class Sanitized < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code)
      end
    end
  end
end
