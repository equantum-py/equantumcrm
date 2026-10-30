# JSON API for other services. Authenticates with a Bearer token issued to an
# ApiClient; there is no browser session, cookie or CSRF token here.
module Api
  module V1
    class BaseController < ActionController::API
      before_action :set_request_context
      before_action :authenticate_client!

      private
        def authenticate_client!
          token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
          @api_client = ApiClient.authenticate(token)
          return render_error(401, "unauthorized", "Token ausente o inválido") unless @api_client

          Current.api_client = @api_client
          @api_client.touch_last_used!
        end

        def require_scope!(scope)
          render_error(403, "forbidden", "El token no tiene el alcance #{scope}") unless @api_client.allowed?(scope)
        end

        def set_request_context
          Current.ip_address = request.remote_ip
          Current.request_id = request.request_id
        end

        def render_error(status, code, message, details = nil)
          error = { "code" => code, "message" => message }
          error["details"] = details if details
          render json: { "error" => error }, status: status
        end
    end
  end
end
