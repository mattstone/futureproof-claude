require "test_helper"

class AgentActionTest < ActiveSupport::TestCase
  setup do
    @agent = ai_agents(:customer_success_manager)
    @application = applications(:mortgage_application)
  end

  test "creates a valid agent action" do
    action = AgentAction.create!(
      ai_agent: @agent,
      actionable: @application,
      action_type: "evaluate",
      decision: "approve",
      confidence: 0.95,
      reasoning: "All checks passed",
      status: "completed"
    )
    assert action.persisted?
    assert_equal @agent, action.ai_agent
    assert_equal @application, action.actionable
  end

  test "validates action_type inclusion" do
    action = AgentAction.new(ai_agent: @agent, action_type: "invalid")
    assert_not action.valid?
    assert_includes action.errors[:action_type], "is not included in the list"
  end

  test "validates confidence range" do
    action = AgentAction.new(ai_agent: @agent, action_type: "evaluate", confidence: 1.5)
    assert_not action.valid?
    assert action.errors[:confidence].any?
  end

  test "override! sets status and reason" do
    action = AgentAction.create!(
      ai_agent: @agent,
      actionable: @application,
      action_type: "decide",
      decision: "reject",
      confidence: 0.8,
      reasoning: "Auto rejected",
      status: "completed"
    )

    action.override!(by: "admin@example.com", reason: "Manual review passed")
    action.reload

    assert_equal "overridden", action.status
    assert_equal "admin@example.com", action.overridden_by
    assert_equal "Manual review passed", action.override_reason
  end

  test "scopes work correctly" do
    AgentAction.create!(ai_agent: @agent, actionable: @application, action_type: "evaluate", decision: "approve", status: "completed")
    AgentAction.create!(ai_agent: @agent, actionable: @application, action_type: "decide", decision: "flag", status: "completed")

    assert_equal 1, AgentAction.evaluations.count
    assert_equal 1, AgentAction.decisions.count
    assert_equal 2, AgentAction.for_entity(@application).count
    assert_equal 2, AgentAction.by_agent(@agent).count
  end
end
