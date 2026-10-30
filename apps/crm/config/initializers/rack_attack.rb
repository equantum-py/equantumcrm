# Coarse request throttling in addition to the per-action rate_limit on sign in.
class Rack::Attack
  throttle("req/ip", limit: 300, period: 1.minute) { |req| req.ip unless req.path.start_with?("/assets") }
  throttle("api/token", limit: 120, period: 1.minute) do |req|
    Digest::SHA256.hexdigest(req.get_header("HTTP_AUTHORIZATION").to_s) if req.path.start_with?("/api/")
  end
  throttle("sessions/ip", limit: 20, period: 5.minutes) { |req| req.ip if req.path == "/session" && req.post? }
end

Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?
