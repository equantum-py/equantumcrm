# Coarse request throttling in addition to the per-action rate_limit on sign in.
class Rack::Attack
  throttle("req/ip", limit: 300, period: 1.minute) { |req| req.ip unless req.path.start_with?("/assets") }
  throttle("sessions/ip", limit: 20, period: 5.minutes) { |req| req.ip if req.path == "/session" && req.post? }
end

Rails.application.config.middleware.use Rack::Attack unless Rails.env.test?
