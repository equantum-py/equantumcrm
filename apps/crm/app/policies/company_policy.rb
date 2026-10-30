class CompanyPolicy < ApplicationPolicy
  def index? = user.can?(:"companies.read")
  def create? = user.can?(:"companies.write")
  def update? = user.can?(:"companies.write")
  def destroy? = user.admin?
end
