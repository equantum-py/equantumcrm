# Builds signed, synthetic Meta webhook deliveries. No real account, number or
# person is ever used: phone numbers are from a reserved synthetic range.
module MetaWebhookHelper
  APP_SECRET = "secreto-de-prueba-no-real".freeze
  VERIFY_TOKEN = "token-de-verificacion-de-prueba".freeze
  ENABLED_ENV = { "META_WEBHOOKS_ENABLED" => "true", "META_APP_SECRET" => APP_SECRET, "META_VERIFY_TOKEN" => VERIFY_TOKEN }.freeze

  def with_env(values)
    previous = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def sign(body, secret: APP_SECRET)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
  end

  def post_meta(body, signature: :valid, headers: {})
    raw = body.is_a?(String) ? body : JSON.generate(body)
    signature_header = signature == :valid ? sign(raw) : signature
    request_headers = { "CONTENT_TYPE" => "application/json" }.merge(headers)
    request_headers["X-Hub-Signature-256"] = signature_header if signature_header
    post "/webhooks/meta", params: raw, headers: request_headers
  end

  def whatsapp_body(message_id: "wamid.E2E-#{SecureRandom.hex(6)}", wa_id: "595981000111", text: "Hola, quiero una tienda online",
                    phone_number_id: "E2E-PNID-1", statuses: [])
    {
      "object" => "whatsapp_business_account",
      "entry" => [ {
        "id" => "E2E-WABA-1",
        "changes" => [ {
          "field" => "messages",
          "value" => {
            "messaging_product" => "whatsapp",
            "metadata" => { "display_phone_number" => "595000000000", "phone_number_id" => phone_number_id },
            "contacts" => [ { "profile" => { "name" => "Contacto Sintético" }, "wa_id" => wa_id } ],
            "messages" => message_id ? [ { "from" => wa_id, "id" => message_id, "timestamp" => Time.current.to_i.to_s,
                                            "type" => "text", "text" => { "body" => text } } ] : [],
            "statuses" => statuses
          }
        } ]
      } ]
    }
  end

  def leadgen_body(leadgen_id: "E2E-LEAD-#{SecureRandom.hex(6)}", page_id: "E2E-PAGE-1")
    {
      "object" => "page",
      "entry" => [ { "id" => page_id, "time" => Time.current.to_i,
                     "changes" => [ { "field" => "leadgen",
                                      "value" => { "leadgen_id" => leadgen_id, "page_id" => page_id, "form_id" => "E2E-FORM-1",
                                                   "ad_id" => "E2E-AD-1", "created_time" => Time.current.to_i } } ] } ]
    }
  end
end
