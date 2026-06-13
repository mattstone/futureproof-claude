require "test_helper"

class AdminAgentMetricsServiceTest < ActiveSupport::TestCase
  setup do
    @akane = ai_agents(:akane)
    @rie = ai_agents(:rie)
    @app = applications(:submitted_application)
  end

  test "summary returns zeros when no actions exist" do
    summary = AdminAgentMetricsService.new.summary

    assert_equal 0, summary[:total_today]
    assert_equal 0, summary[:total_week]
    assert_equal 0, summary[:total_all]
    assert_equal 0, summary[:avg_confidence]
    assert_equal 0, summary[:flags_count]
    assert_equal 0, summary[:escalations_count]
    assert_equal({}, summary[:decision_distribution])
  end

  test "summary aggregates today/week/all counts and decisions" do
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "approve", status: "completed", confidence: 0.9, created_at: Time.current)
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "flag",    status: "completed", confidence: 0.6, created_at: 2.days.ago)
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "escalate", decision: "reject",  status: "completed", confidence: 0.4, created_at: 30.days.ago)

    summary = AdminAgentMetricsService.new.summary

    assert_equal 1, summary[:total_today]
    assert_equal 2, summary[:total_week]
    assert_equal 3, summary[:total_all]
    assert_in_delta 0.63, summary[:avg_confidence], 0.01
    assert_equal 1, summary[:flags_count]
    assert_equal 1, summary[:escalations_count]
    assert_equal 1, summary[:decision_distribution]["approve"]
    assert_equal 1, summary[:decision_distribution]["flag"]
    assert_equal 1, summary[:decision_distribution]["reject"]
  end

  test "cards returns one card per active agent" do
    cards = AdminAgentMetricsService.new.cards
    agent_ids = cards.map { |c| c.agent.id }

    assert_includes agent_ids, @akane.id
    assert_includes agent_ids, @rie.id
  end

  test "card computes approval rate and last action correctly" do
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "approve", status: "completed", confidence: 0.9)
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "approve", status: "completed", confidence: 0.8)
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "flag",    status: "completed", confidence: 0.5)

    card = AdminAgentMetricsService.new.cards.find { |c| c.agent.id == @akane.id }

    assert_equal 3, card.total
    assert_equal 66.7, card.approval_rate
    assert_in_delta 0.73, card.avg_confidence, 0.01
    assert card.active, "agent with action in last hour should be active"
  end

  test "card marks agent inactive when last action is older than 1 hour" do
    AgentAction.create!(ai_agent: @akane, actionable: @app, action_type: "evaluate", decision: "approve", status: "completed", confidence: 0.9, created_at: 2.hours.ago)

    card = AdminAgentMetricsService.new.cards.find { |c| c.agent.id == @akane.id }

    refute card.active
  end

  test "call returns combined summary, cards, and roster" do
    result = AdminAgentMetricsService.new.call

    assert_kind_of Hash, result[:summary]
    assert_kind_of Array, result[:cards]
    assert_respond_to result[:roster].performances, :each
    assert_respond_to result[:roster].recent_tasks, :each
  end
end
