class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Demasiados intentos. Probá de nuevo en unos minutos." }
  layout "auth", only: :new

  def new
  end

  def create
    user = User.active.authenticate_by(params.permit(:email_address, :password))
    if user
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Correo o contraseña incorrectos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    def skip_authorization_check? = true
end
