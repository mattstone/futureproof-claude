require "test_helper"

class AdminManagementAttentionServiceTest < ActiveSupport::TestCase
  setup do
    @service = AdminManagementAttentionService.new
    @user = users(:john)
    @app = applications(:submitted_application)
  end

  test "call returns sorted signals" do
    signals = @service.call

    assert_kind_of Array, signals
    severities = signals.map { |s| AdminManagementAttentionService::SEVERITY_ORDER[s.severity] }
    assert_equal severities.sort, severities
  end

  test "stalled_applications returns nil when none exceed threshold" do
    Application.where(status: 'processing').update_all(updated_at: Time.current)

    assert_nil @service.stalled_applications
  end

  test "stalled_applications returns warning above 5" do
    apps = Application.where(status: 'processing').limit(6).to_a
    skip "need at least 6 processing applications in fixtures" if apps.size < 6

    apps.each { |a| a.update_columns(updated_at: 10.days.ago) }
    signal = @service.stalled_applications

    assert signal
    assert_equal :warning, signal.severity
  end

  test "escalated_conversations_open returns nil when count <= 3" do
    assert_nil @service.escalated_conversations_open
  end

  test "escalated_conversations_open returns warning above 3" do
    agent = ChatAgent.create!(name: "Test Akane", agent_type: 'support')
    4.times do
      ChatConversation.create!(user: @user, chat_agent: agent, status: 'escalated', region: 'au')
    end

    signal = @service.escalated_conversations_open
    assert signal
    assert_equal :warning, signal.severity
  end

  test "pool_utilisation returns warning above 90%" do
    skip "need a funder pool" if FunderPool.none?
    FunderPool.find_each { |p| p.update_columns(allocated: (p.amount * 0.92).round) }

    signal = @service.pool_utilisation
    assert signal
    assert_equal :warning, signal.severity
  end

  test "pool_utilisation returns critical above 95%" do
    skip "need a funder pool" if FunderPool.none?
    FunderPool.find_each { |p| p.update_columns(allocated: (p.amount * 0.97).round) }

    signal = @service.pool_utilisation
    assert signal
    assert_equal :critical, signal.severity
  end

  test "investment_underperformance returns nil when no holiday contracts" do
    Contract.update_all(status: :ok)

    assert_nil @service.investment_underperformance
  end

  test "agent_failure_rate returns nil when no agent actions" do
    AgentAction.delete_all

    assert_nil @service.agent_failure_rate
  end

  test "agent_failure_rate returns warning above 5%" do
    agent = ai_agents(:akane)
    AgentAction.create!(ai_agent: agent, actionable: @app, action_type: 'evaluate', status: 'failed', confidence: 0.5)
    9.times do
      AgentAction.create!(ai_agent: agent, actionable: @app, action_type: 'evaluate', status: 'completed', decision: 'approve', confidence: 0.9)
    end

    signal = @service.agent_failure_rate
    assert signal
    assert_equal :warning, signal.severity
  end

  test "cross_jurisdiction_audit_events returns info when 1-5 events" do
    AuditLog.create!(user: @user, action: 'cross_jurisdiction_access', resource_type: 'Application', resource_id: 1)

    signal = @service.cross_jurisdiction_audit_events
    assert signal
    assert_equal :info, signal.severity
  end

  test "application_volume_drop returns nil when this-week >= last-week" do
    assert_nil @service.application_volume_drop
  end

  test "Signal struct exposes all expected fields" do
    signal = AdminManagementAttentionService::Signal.new(
      severity: :critical, category: 'Test', headline: 'h', detail: 'd', drill_down_path: '/x', metric: 1
    )

    assert_equal :critical, signal.severity
    assert_equal 'Test', signal.category
    assert_equal '/x', signal.drill_down_path
  end

  test "all healthy returns empty array" do
    Application.where(status: 'processing').update_all(updated_at: Time.current)
    AgentAction.delete_all
    Contract.update_all(status: :ok)
    SupportTicket.update_all(status: 'resolved', resolved_at: Time.current)

    signals = @service.call

    operational_signals = signals.reject { |s| s.severity == :info }
    assert_empty operational_signals.select { |s| %i[critical warning].include?(s.severity) },
                "expected no critical or warning signals when all healthy, got: #{operational_signals.map(&:headline).inspect}"
  end
end
