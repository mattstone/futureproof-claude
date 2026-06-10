require "test_helper"

class AdminAttentionInboxServiceTest < ActiveSupport::TestCase
  setup do
    @agent = ai_agents(:akane)
    @app = applications(:submitted_application)
  end

  test "returns empty array when nothing needs attention" do
    assert_empty AdminAttentionInboxService.new.call
  end

  test "surfaces flagged agent actions" do
    action = AgentAction.create!(
      ai_agent: @agent,
      actionable: @app,
      action_type: 'evaluate',
      decision: 'flag',
      status: 'completed',
      confidence: 0.85,
      reasoning: 'Borrower age over 75'
    )

    items = AdminAttentionInboxService.new.call

    assert_equal 1, items.size
    item = items.first
    assert_equal :agent_flag, item.type
    assert_equal action.id, item.action_id
    assert_equal 'Application', item.resource_type
    assert_equal @app.id, item.resource_id
    assert_includes item.title, "Application ##{@app.id}"
    assert_includes item.subtitle, '85%'
  end

  test "skips overridden agent actions" do
    AgentAction.create!(
      ai_agent: @agent, actionable: @app,
      action_type: 'evaluate', decision: 'flag',
      status: 'overridden', confidence: 0.85
    )

    assert_empty AdminAttentionInboxService.new.call
  end

  test "surfaces low-confidence actions below 0.7" do
    AgentAction.create!(
      ai_agent: @agent, actionable: @app,
      action_type: 'evaluate', decision: 'approve',
      status: 'completed', confidence: 0.5,
      reasoning: 'Uncertain on income docs'
    )

    items = AdminAttentionInboxService.new.call

    assert_equal 1, items.size
    assert_equal :low_confidence, items.first.type
    assert_includes items.first.subtitle, '50%'
  end

  test "ignores high-confidence actions" do
    AgentAction.create!(
      ai_agent: @agent, actionable: @app,
      action_type: 'evaluate', decision: 'approve',
      status: 'completed', confidence: 0.95
    )

    assert_empty AdminAttentionInboxService.new.call
  end

  test "does not double-count an action that is both flagged and low-confidence" do
    AgentAction.create!(
      ai_agent: @agent, actionable: @app,
      action_type: 'evaluate', decision: 'flag',
      status: 'completed', confidence: 0.5
    )

    items = AdminAttentionInboxService.new.call

    assert_equal 1, items.size
    assert_equal :agent_flag, items.first.type
  end

  test "groups unverified documents per application" do
    ApplicationDocument.create!(application: @app, document_type: 'identity', status: 'uploaded')
    ApplicationDocument.create!(application: @app, document_type: 'income_proof', status: 'pending')

    items = AdminAttentionInboxService.new.call

    assert_equal 1, items.size
    assert_equal :document_review, items.first.type
    assert_equal @app.id, items.first.resource_id
    assert_includes items.first.title, '2 documents'
  end

  test "skips orphaned agent actions with no actionable" do
    AgentAction.create!(
      ai_agent: @agent, actionable: nil,
      action_type: 'evaluate', decision: 'flag',
      status: 'completed', confidence: 0.85
    )

    assert_empty AdminAttentionInboxService.new.call
  end

  test "sorts items by created_at descending and caps at MAX_ITEMS" do
    15.times do |i|
      AgentAction.create!(
        ai_agent: @agent, actionable: @app,
        action_type: 'evaluate', decision: 'flag',
        status: 'completed', confidence: 0.8,
        created_at: i.hours.ago
      )
    end

    items = AdminAttentionInboxService.new.call

    assert_equal AdminAttentionInboxService::MAX_ITEMS, items.size
    assert_equal items, items.sort_by { |i| -i.created_at.to_i }
  end

end
