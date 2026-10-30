class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_request_context
  after_action :verify_authorized, unless: :skip_authorization_check?

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  helper_method :current_user

  private
    def current_user = Current.user
    def pundit_user = Current.user

    def set_request_context
      Current.ip_address = request.remote_ip
      Current.request_id = request.request_id
    end

    def skip_authorization_check?
      false
    end

    def forbidden
      respond_to do |format|
        format.html { redirect_back_or_to root_path, alert: "No tenés permiso para esa acción." }
        format.any { head :forbidden }
      end
    end

    def not_found
      respond_to do |format|
        format.html { redirect_to root_path, alert: "El registro no existe o fue eliminado." }
        format.any { head :not_found }
      end
    end
end
