# Meta configuration, read from the environment on every call so a change in
# /etc/arm/arm.env takes effect on restart and tests can toggle it.
module Meta
  module Settings
    module_function

    def webhooks_enabled? = ENV["META_WEBHOOKS_ENABLED"] == "true"
    def app_secret = ENV["META_APP_SECRET"].to_s
    def verify_token = ENV["META_VERIFY_TOKEN"].to_s
  end
end
