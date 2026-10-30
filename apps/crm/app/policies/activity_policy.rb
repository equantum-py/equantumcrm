class ActivityPolicy < ApplicationPolicy
  def index? = user.can?(:"activities.write")
  def create? = user.can?(:"activities.write")
  def update? = create? && (record.owner_id == user.id || user.can?(:"pipeline.manage_all"))
  def complete? = update?
  def destroy? = update?
end
