# Receives Meta webhooks (plan r2, 2.2 and 7.1). It only verifies, stores and
# answers: processing happens in Solid Queue. Nothing here calls Meta or sends
# a message.
module Webhooks
  class MetaController < ActionController::API
    MAX_BODY_BYTES = 1.megabyte
    RATE_LIMIT = 600
    # Production uses the app cache (Solid Cache); tests get their own store
    # so they can reset it.
    RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

    rate_limit to: RATE_LIMIT, within: 1.minute, only: :receive, store: RATE_LIMIT_STORE,
               with: -> { head :too_many_requests }
    before_action :require_enabled

    # GET /webhooks/meta: subscription check from the Meta app dashboard.
    def verify
      token_ok = Meta::Settings.verify_token.present? &&
                 ActiveSupport::SecurityUtils.secure_compare(params["hub.verify_token"].to_s, Meta::Settings.verify_token)
      if params["hub.mode"] == "subscribe" && token_ok
        render plain: params["hub.challenge"].to_s, status: :ok
      else
        head :forbidden
      end
    end

    # POST /webhooks/meta: one delivery, possibly with several entries.
    def receive
      return head(:content_too_large) if request.content_length.to_i > MAX_BODY_BYTES

      raw = request.raw_post
      return head(:content_too_large) if raw.bytesize > MAX_BODY_BYTES

      unless Meta::SignatureVerifier.new(Meta::Settings.app_secret).valid?(raw, request.headers["X-Hub-Signature-256"])
        Rails.logger.warn("[meta-webhook] firma inválida o ausente (#{raw.bytesize} bytes)")
        return head(:unauthorized)
      end

      body = JSON.parse(raw)
      return head(:bad_request) unless body.is_a?(Hash)

      Meta::EventRecorder.new(body).call
      render json: {}, status: :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private
      def require_enabled
        head :not_found unless Meta::Settings.webhooks_enabled?
      end
  end
end
