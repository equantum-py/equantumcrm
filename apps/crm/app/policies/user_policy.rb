class UserPolicy < ApplicationPolicy
  def index? = user.can?(:"users.manage")
  def create? = index?
  def update? = index?
end
