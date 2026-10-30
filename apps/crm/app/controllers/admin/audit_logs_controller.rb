class Admin::AuditLogsController < ApplicationController
  def index
    authorize AuditLog
    @logs = AuditLog.includes(:actor).recent
    @logs = @logs.where(auditable_type: params[:type]) if params[:type].present?
    @logs = @logs.limit(200)
  end
end
