class OpportunityPolicy < ApplicationPolicy
  def index? = user.can?(:"pipeline.read")
  def create? = user.can?(:"pipeline.write")

  # Sales users edit their own deals; managers and admins edit all of them.
  def update?
    user.can?(:"pipeline.write") && (record.owner_id == user.id || user.can?(:"pipeline.manage_all"))
  end

  def move? = update?
  def destroy? = user.admin?
end
