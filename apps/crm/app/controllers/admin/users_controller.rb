class Admin::UsersController < ApplicationController
  before_action :set_user, only: %i[edit update]

  def index
    authorize User
    @users = User.includes(:role).ordered
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user
    if @user.save
      redirect_to admin_users_path, notice: "Usuario creado."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    attrs = user_params
    attrs = attrs.except(:password) if attrs[:password].blank?
    if @user == current_user && (attrs[:active] == "0" || (attrs[:role_id].present? && attrs[:role_id].to_i != @user.role_id))
      redirect_to edit_admin_user_path(@user), alert: "No podés desactivarte ni cambiar tu propio rol." and return
    end

    if @user.update(attrs)
      @user.sessions.destroy_all unless @user.active?
      redirect_to admin_users_path, notice: "Usuario actualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :name, :email_address, :password, :role_id, :active ])
    end
end
