class LeadPolicy < ApplicationPolicy
  def index? = user.can?(:"leads.read")
  def create? = user.can?(:"leads.write")
  def update? = user.can?(:"leads.write")
  def destroy? = user.admin?
  def score? = update?
  def review_analysis? = user.can?(:"ai.review")
  def convert? = update? && user.can?(:"pipeline.write")
end
