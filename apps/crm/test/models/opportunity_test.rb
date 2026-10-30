require "test_helper"

class OpportunityTest < ActiveSupport::TestCase
  setup { @owner = create_user }

  test "moving to won or lost stamps dates and lost requires a reason" do
    opportunity = create_opportunity(owner: @owner)
    won = PipelineStage.find_by!(kind: "won")
    lost = PipelineStage.find_by!(kind: "lost")

    opportunity.update!(pipeline_stage: won)
    assert opportunity.won_at

    assert_not opportunity.update(pipeline_stage: lost)
    assert opportunity.update(pipeline_stage: lost, lost_reason: "Eligió otro proveedor")
    assert_nil opportunity.won_at
    assert opportunity.lost_at
  end

  test "value is stored in minor units of its currency" do
    opportunity = create_opportunity(owner: @owner, currency: "PYG", estimated_value: "2500000")
    assert_equal 2_500_000, opportunity.estimated_value_cents
    assert_equal "PYG 2.500.000", opportunity.estimated_value.to_s
  end

  test "value requires a currency" do
    opportunity = Opportunity.new(name: "x", company: create_company, owner: @owner, pipeline_stage: PipelineStage.ordered.first, estimated_value_cents: 100)
    assert_not opportunity.valid?
  end
end
