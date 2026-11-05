# Splits a verified Meta delivery into one WebhookEvent per entry and stores
# each one exactly once (unique event_key). New pending events are enqueued
# for processing; duplicates are counted and skipped. It makes no external
# call, so the controller can answer 200 quickly.
module Meta
  class EventRecorder
    Result = Data.define(:created, :duplicates, :ignored)
    Fragment = Data.define(:event_key, :object_type, :channel_kind, :account_id, :summary, :payload)

    KNOWN_OBJECTS = { "whatsapp_business_account" => "whatsapp", "page" => "meta_lead_ads", "instagram" => "instagram" }.freeze

    def initialize(body, received_at: Time.current)
      @body = body
      @received_at = received_at
    end

    def call
      created = []
      duplicates = 0
      ignored = 0
      fragments.each do |fragment|
        event = store(fragment)
        if event.nil?
          duplicates += 1
        elsif event.status == "ignored"
          ignored += 1
        else
          created << event
        end
      end
      created.each { |event| enqueue(event) }
      Result.new(created: created.size, duplicates: duplicates, ignored: ignored)
    end

    def fragments
      object = @body["object"].to_s
      entries = Array(@body["entry"]).select { |entry| entry.is_a?(Hash) }
      case object
      when "whatsapp_business_account" then entries.flat_map { |entry| whatsapp_fragments(entry) }
      when "page" then entries.flat_map { |entry| page_fragments(entry) }
      when "instagram" then entries.flat_map { |entry| instagram_fragments(entry) }
      else entries.map { |entry| raw_fragment(object.presence || "unknown", nil, entry["id"], entry) }
      end
    end

    private
      def whatsapp_fragments(entry)
        Array(entry["changes"]).flat_map do |change|
          value = change.is_a?(Hash) ? change["value"] : nil
          next [ raw_fragment("whatsapp_business_account", "whatsapp", entry["id"], change) ] unless change.is_a?(Hash) && change["field"] == "messages" && value.is_a?(Hash)

          account = value.dig("metadata", "phone_number_id").to_s.presence || entry["id"]
          context = { "field" => "messages", "metadata" => value["metadata"] }
          messages = Array(value["messages"]).select { |m| m.is_a?(Hash) && m["id"].present? }.map do |message|
            profile = Array(value["contacts"]).find { |c| c.is_a?(Hash) && c["wa_id"] == message["from"] }
            build("wa:msg:#{message['id']}", "whatsapp_business_account", "whatsapp", account,
                  { "kind" => "wa_message", "external_id" => message["id"], "message_type" => message["type"],
                    "sender_digest" => digest(message["from"]), "occurred_at" => unix_time(message["timestamp"]) },
                  context.merge("contact" => profile, "message" => message))
          end
          statuses = Array(value["statuses"]).select { |s| s.is_a?(Hash) && s["id"].present? }.map do |status|
            build("wa:st:#{status['id']}:#{status['status']}", "whatsapp_business_account", "whatsapp", account,
                  { "kind" => "wa_status", "external_id" => status["id"], "status" => status["status"],
                    "sender_digest" => digest(status["recipient_id"]), "occurred_at" => unix_time(status["timestamp"]) },
                  context.merge("status" => status))
          end
          other = messages.empty? && statuses.empty? ? [ raw_fragment("whatsapp_business_account", "whatsapp", account, change) ] : []
          messages + statuses + other
        end
      end

      def page_fragments(entry)
        Array(entry["changes"]).map do |change|
          value = change.is_a?(Hash) ? change["value"] : nil
          if change.is_a?(Hash) && change["field"] == "leadgen" && value.is_a?(Hash) && value["leadgen_id"].present?
            account = value["page_id"].to_s.presence || entry["id"]
            build("fb:lead:#{value['leadgen_id']}", "page", "meta_lead_ads", account,
                  { "kind" => "leadgen", "external_id" => value["leadgen_id"].to_s, "form_id" => value["form_id"].to_s,
                    "occurred_at" => unix_time(value["created_time"]) },
                  { "field" => "leadgen", "value" => value })
          else
            raw_fragment("page", "meta_lead_ads", entry["id"], change)
          end
        end
      end

      def instagram_fragments(entry)
        Array(entry["messaging"]).map do |event|
          mid = event.is_a?(Hash) ? event.dig("message", "mid") : nil
          if mid.present?
            build("ig:msg:#{mid}", "instagram", "instagram", entry["id"],
                  { "kind" => "ig_message", "external_id" => mid, "sender_digest" => digest(event.dig("sender", "id")),
                    "occurred_at" => unix_time(event["timestamp"].to_i / 1000) },
                  { "messaging" => event })
          else
            raw_fragment("instagram", "instagram", entry["id"], event)
          end
        end
      end

      # Anything without a stable id is keyed by the hash of its own content.
      def raw_fragment(object_type, channel_kind, account_id, content)
        json = JSON.generate(content)
        build("raw:#{Digest::SHA256.hexdigest(json)}", object_type, channel_kind, account_id,
              { "kind" => "other" }, { "raw" => content })
      end

      def build(key, object_type, channel_kind, account_id, summary, payload)
        Fragment.new(event_key: key.truncate(255, omission: ""), object_type: object_type, channel_kind: channel_kind,
                     account_id: account_id.to_s.presence, summary: summary.compact, payload: payload)
      end

      def store(fragment)
        channel = channel_for(fragment)
        status = recognized?(fragment) ? "pending" : "ignored"
        event = WebhookEvent.create!(
          provider: "meta", object_type: fragment.object_type, event_key: fragment.event_key, channel: channel,
          payload: JSON.generate(fragment.payload), summary: fragment.summary, status: status,
          received_at: @received_at, processed_at: (status == "ignored" ? @received_at : nil)
        )
        channel&.update_column(:last_event_at, @received_at)
        event
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def recognized?(fragment)
        KNOWN_OBJECTS.key?(fragment.object_type) && fragment.summary["kind"] != "other"
      end

      def channel_for(fragment)
        return if fragment.channel_kind.nil? || fragment.account_id.nil?

        Channel.find_by(kind: fragment.channel_kind, external_account_id: fragment.account_id)
      end

      def enqueue(event)
        event.update_column(:last_enqueued_at, Time.current)
        Channels::ProcessWebhookEventJob.perform_later(event)
      end

      def digest(value)
        value.present? ? Digest::SHA256.hexdigest("arm-sender:#{value}")[0, 32] : nil
      end

      def unix_time(value)
        seconds = Integer(value.to_s, exception: false)
        seconds && seconds.positive? ? Time.at(seconds).utc.iso8601 : nil
      end
  end
end
