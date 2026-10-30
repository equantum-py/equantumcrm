class AuditLogPolicy < ApplicationPolicy
  def index? = user.can?(:"audit.read")
end
