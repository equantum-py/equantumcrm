require "test_helper"

# PR-1 acceptance for the Meta webhook receiver (plan r2, 12.1: S01–S05,
# S17, S18 and the receiver limits). All payloads are synthetic and signed
# with a test secret; no Meta account is contacted.
class MetaWebhooksTest < ActionDispatch::IntegrationTest
  include MetaWebhookHelper
  include ActiveJob::TestHelper

  setup { Webhooks::MetaController::RATE_LIMIT_STORE.clear }

  def around_enabled(&block) = with_env(ENABLED_ENV, &block)

  # S01
  test "verification returns the exact challenge with the right token" do
    around_enabled do
      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => VERIFY_TOKEN, "hub.challenge" => "1158201444" }
      assert_response :ok
      assert_equal "1158201444", response.body
      assert_equal "text/plain", response.media_type
    end
  end

  test "verification rejects a wrong token or mode with 403" do
    around_enabled do
      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => "otro", "hub.challenge" => "1" }
      assert_response :forbidden
      assert_empty response.body
      get "/webhooks/meta", params: { "hub.mode" => "unsubscribe", "hub.verify_token" => VERIFY_TOKEN, "hub.challenge" => "1" }
      assert_response :forbidden
    end
  end

  test "both endpoints answer 404 while the flag is off" do
    with_env(ENABLED_ENV.merge("META_WEBHOOKS_ENABLED" => nil)) do
      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => VERIFY_TOKEN, "hub.challenge" => "1" }
      assert_response :not_found
      assert_no_difference -> { WebhookEvent.count } do
        post_meta(whatsapp_body)
      end
      assert_response :not_found
    end
  end

  # S02
  test "invalid, missing or tampered signatures answer 401 and store nothing" do
    around_enabled do
      body = JSON.generate(whatsapp_body)
      assert_no_difference -> { WebhookEvent.count } do
        post_meta(body, signature: sign(body, secret: "otro-secreto"))
        assert_response :unauthorized
        post_meta(body, signature: nil)
        assert_response :unauthorized
        post_meta(body.sub("tienda", "tiendas"), signature: sign(body))
        assert_response :unauthorized
        post_meta(body, signature: "sha1=#{'0' * 40}")
        assert_response :unauthorized
      end
      assert_no_enqueued_jobs
    end
  end

  test "a missing app secret never accepts a delivery" do
    with_env(ENABLED_ENV.merge("META_APP_SECRET" => nil)) do
      body = JSON.generate(whatsapp_body)
      assert_no_difference -> { WebhookEvent.count } do
        post_meta(body, signature: sign(body, secret: ""))
      end
      assert_response :unauthorized
    end
  end

  # S03
  test "the signature is checked over the raw bytes, including non-ASCII text" do
    around_enabled do
      body = JSON.generate(whatsapp_body(text: "¿Cuánto cuesta una tienda? Ñandutí 🧉"))
      assert_difference -> { WebhookEvent.count } => 1 do
        post_meta(body)
      end
      assert_response :ok
      assert_equal({}, response.parsed_body)
    end
  end

  # S04
  test "bodies over 1 MB answer 413" do
    around_enabled do
      body = JSON.generate(whatsapp_body(text: "x" * (1.megabyte + 10)))
      assert_no_difference -> { WebhookEvent.count } do
        post_meta(body)
      end
      assert_response :content_too_large
    end
  end

  test "malformed JSON with a valid signature answers 400" do
    around_enabled do
      post_meta("{no es json")
      assert_response :bad_request
    end
  end

  # S05
  test "the same delivery three times stores one event and enqueues it once" do
    around_enabled do
      body = whatsapp_body(message_id: "wamid.E2E-dup-#{SecureRandom.hex(4)}")
      assert_difference -> { WebhookEvent.count } => 1 do
        assert_enqueued_jobs 1, only: Channels::ProcessWebhookEventJob do
          3.times { post_meta(body) }
        end
      end
      assert_response :ok
      event = WebhookEvent.last
      assert_equal "pending", event.status
      assert_equal "whatsapp_business_account", event.object_type
      assert event.event_key.start_with?("wa:msg:")
    end
  end

  test "a delivery with a message and a status stores one event per entry" do
    around_enabled do
      body = whatsapp_body(statuses: [ { "id" => "wamid.E2E-out-1", "status" => "delivered", "timestamp" => Time.current.to_i.to_s,
                                         "recipient_id" => "595981000111" } ])
      assert_difference -> { WebhookEvent.count } => 2 do
        post_meta(body)
      end
      keys = WebhookEvent.order(:id).last(2).map(&:event_key)
      assert(keys.any? { |key| key.start_with?("wa:msg:") })
      assert_includes keys, "wa:st:wamid.E2E-out-1:delivered"
    end
  end

  test "lead ads entries are keyed by leadgen id and linked to their channel" do
    around_enabled do
      channel = Channel.create!(kind: "meta_lead_ads", name: "Página sintética", external_account_id: "E2E-PAGE-1", synthetic: true)
      post_meta(leadgen_body(leadgen_id: "E2E-LEAD-42"))
      event = WebhookEvent.find_by!(event_key: "fb:lead:E2E-LEAD-42")
      assert_equal channel, event.channel
      assert_equal "leadgen", event.summary["kind"]
      assert_equal "E2E-FORM-1", event.summary["form_id"]
      assert_not_nil channel.reload.last_event_at
    end
  end

  test "unknown objects are stored as ignored and never enqueued" do
    around_enabled do
      assert_no_enqueued_jobs do
        post_meta({ "object" => "permissions", "entry" => [ { "id" => "1", "changed_fields" => [ "x" ] } ] })
      end
      assert_response :ok
      assert_equal "ignored", WebhookEvent.last.status
    end
  end

  # S17 (receiver side): the raw fragment is encrypted at rest and summaries
  # and logs carry no phone number or message text.
  test "personal data is neither stored in clear nor logged" do
    around_enabled do
      wa_id = "59598#{rand(1_000_000..9_999_999)}"
      text = "Texto sintético privado #{SecureRandom.hex(4)}"
      log = Rails.root.join("log/test.log")
      offset = File.exist?(log) ? File.size(log) : 0
      post_meta(whatsapp_body(wa_id: wa_id, text: text))
      assert_response :ok

      event = WebhookEvent.last
      raw = WebhookEvent.connection.select_value("SELECT payload FROM webhook_events WHERE id = #{event.id}")
      assert_not_includes raw, wa_id
      assert_not_includes raw, text
      assert_includes event.payload_data.dig("message", "text", "body"), text
      assert_not_includes event.summary.to_json, wa_id

      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      appended = File.exist?(log) ? File.binread(log, nil, offset).force_encoding("UTF-8") : ""
      assert_not_includes appended, wa_id
      assert_not_includes appended, text
    end
  end

  # S18
  test "on the public host only /webhooks/meta exists" do
    with_env(ENABLED_ENV.merge("META_PUBLIC_HOST" => "hooks.e2e.invalid")) do
      [ "/", "/session/new", "/leads", "/up", "/api/v1/lead_ingestions", "/webhooks/meta/x" ].each do |path|
        get path, headers: { "HOST" => "hooks.e2e.invalid" }
        assert_response :not_found, "#{path} should be hidden on the public host"
      end
      get "/webhooks/meta", params: { "hub.mode" => "subscribe", "hub.verify_token" => VERIFY_TOKEN, "hub.challenge" => "7" },
                            headers: { "HOST" => "hooks.e2e.invalid" }
      assert_response :ok
      get "/session/new"
      assert_response :ok
    end
  end

  test "more than 600 deliveries a minute from one address answer 429" do
    around_enabled do
      body = JSON.generate({ "object" => "page", "entry" => [] })
      Webhooks::MetaController::RATE_LIMIT.times { post_meta(body) }
      assert_response :ok
      post_meta(body)
      assert_response :too_many_requests
    end
  end
end
