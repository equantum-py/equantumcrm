# Second barrier behind the tunnel (plan r2, 2.3): on the public webhook host
# (META_PUBLIC_HOST) only /webhooks/meta exists. Every other path answers 404
# before reaching the router, so the CRM is never exposed through that host.
class MetaPublicHostGuard
  ALLOWED_PATH = "/webhooks/meta".freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    public_host = ENV["META_PUBLIC_HOST"].to_s.strip.downcase
    return @app.call(env) if public_host.empty?

    request = Rack::Request.new(env)
    if request.host.to_s.downcase == public_host && request.path_info != ALLOWED_PATH
      return [ 404, { "content-type" => "text/plain", "content-length" => "0" }, [] ]
    end

    @app.call(env)
  end
end
