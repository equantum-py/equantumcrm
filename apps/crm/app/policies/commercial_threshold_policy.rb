class CommercialThresholdPolicy < ApplicationPolicy
  def index? = user.can?(:"rates.read")
  def create? = user.can?(:"rates.manage")
  def update? = user.can?(:"rates.manage")
  def destroy? = user.can?(:"rates.manage")
end
