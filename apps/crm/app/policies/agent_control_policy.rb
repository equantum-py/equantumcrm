class AgentControlPolicy < ApplicationPolicy
  def show? = user.can?(:"agents.read")
end
