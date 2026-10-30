class DashboardPolicy < ApplicationPolicy
  def show? = user.can?(:"dashboard.read")
end
