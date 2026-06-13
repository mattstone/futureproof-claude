require "test_helper"

class Console::AiAgentsCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @agent = ai_agents(:customer_success_manager)
    @application = Application.first!
  end

  def seed_actions!
    AgentAction.create!(ai_agent: @agent, action_type: "decide", decision: "approve",
                        confidence: 0.92, status: "completed", actionable: @application, reasoning: "Clean file.")
    AgentAction.create!(ai_agent: @agent, action_type: "decide", decision: "flag",
                        confidence: 0.55, status: "completed", actionable: @application, reasoning: "Low confidence.")
    AgentAction.create!(ai_agent: @agent, action_type: "decide", decision: "reject",
                        confidence: 0.8, status: "overridden", actionable: @application)
    AgentAction.create!(ai_agent: @agent, action_type: "escalate", status: "completed")
  end

  # --- Per-agent dashboard --------------------------------------------------------

  test "agent show renders decision performance metrics and breakdowns" do
    seed_actions!

    get console_ai_agent_path(@agent)
    assert_response :success
    assert_select ".console-card-title", text: "Decision performance"
    assert_select ".console-stat-label", text: "Approval rate"
    assert_select ".console-stat-label", text: "Flags"
    assert_select ".console-stat-label", text: "Rejections"
    assert_select ".console-stat-label", text: "Overridden"
    assert_select ".console-card-subtitle", text: "Decisions"
    assert_select ".console-card-subtitle", text: "Action types"
    # 4 actions, 1 approve => 25%
    assert_match "25.0%", response.body
  end

  test "action log links to the entity and shows status" do
    seed_actions!

    get console_ai_agent_path(@agent)
    assert_select ".console-card-title", text: "Recent actions"
    assert_select "a[href=?]", console_application_path(@application)
    assert_select ".console-badge", text: "Overridden"
  end

  # --- Task queue ------------------------------------------------------------------

  test "agent show surfaces the task backlog including escalations" do
    perf = AgentPerformance.create!(agent_name: @agent.name, agent_type: "ai", status: "idle")
    AgentTask.create!(agent_performance: perf, task_type: "document_verify", status: "pending", priority: "normal")
    AgentTask.create!(agent_performance: perf, task_type: "compliance_check", status: "escalated", priority: "high")

    get console_ai_agent_path(@agent)
    assert_select ".console-card-title", text: "Task queue"
    assert_select ".console-dl-term", text: "Escalated"
    assert_match "escalated — needs a human", response.body
  end

  # --- Timeline --------------------------------------------------------------------

  test "timeline lists cross-agent actions and filters by decision" do
    seed_actions!

    get timeline_console_ai_agents_path
    assert_response :success
    assert_match "Agent action timeline", response.body
    assert_select ".console-doc-item", minimum: 4

    get timeline_console_ai_agents_path(decision: "reject")
    assert_select ".console-doc-item", count: 1
  end

  test "timeline filters by agent" do
    seed_actions!
    get timeline_console_ai_agents_path(agent_id: @agent.id)
    assert_response :success
    assert_select ".console-doc-item", minimum: 4
  end

  # --- Lifecycle editor regressions ------------------------------------------------

  test "edit stage offers handoff dropdown, colour picker and multiple action rows" do
    @agent.update!(lifecycle_stages: [ {
      "stage_name" => "welcome", "stage_label" => "Welcome", "stage_color" => "green",
      "automated_actions" => [
        { "action_type" => "send_email", "email_template_id" => EmailTemplate.first&.id, "delay" => { "duration" => 0, "unit" => "minutes" } },
        { "action_type" => "create_task", "task_type" => "customer_query", "delay" => { "duration" => 1, "unit" => "hours" } }
      ],
      "exit_conditions" => { "after" => "first_reply" }, "handoff_rules" => {}
    } ])

    get edit_stage_console_ai_agent_path(@agent, stage_index: 0)
    assert_response :success
    assert_select "select#stage_color"
    assert_select "select#handoff_to"
    # two existing actions + one blank row = 3 action rows
    assert_select ".console-action-row", count: 3
  end

  test "saving a multi-action stage preserves all actions and exit conditions" do
    @agent.update!(lifecycle_stages: [ {
      "stage_name" => "welcome", "stage_label" => "Welcome", "stage_color" => "green",
      "automated_actions" => [], "exit_conditions" => { "after" => "first_reply" }, "handoff_rules" => {}
    } ])

    patch update_stage_console_ai_agent_path(@agent), params: {
      stage_index: 0, stage_label: "Welcome", stage_name: "welcome", stage_color: "amber",
      handoff_to: ai_agents(:funding_specialist).name,
      automated_actions: [
        { action_type: "send_email", email_template_id: EmailTemplate.first&.id, delay: { duration: "0", unit: "minutes" } },
        { action_type: "create_task", task_type: "document_verify", delay: { duration: "2", unit: "hours" } },
        { action_type: "" } # blank trailing row is dropped
      ]
    }
    assert_redirected_to console_ai_agent_path(@agent)

    stage = @agent.reload.lifecycle_stages.first
    assert_equal 2, stage["automated_actions"].size
    assert_equal "amber", stage["stage_color"]
    assert_equal ai_agents(:funding_specialist).name, stage.dig("handoff_rules", "handoff_to")
    assert_equal({ "after" => "first_reply" }, stage["exit_conditions"]) # preserved, not wiped
  end
end
