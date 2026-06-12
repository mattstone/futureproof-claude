require "test_helper"

class Console::AiAgentsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @agent = ai_agents(:akane)
  end

  test "index renders roster, performance and recent tasks" do
    AgentPerformance.create!(agent_name: @agent.name, agent_type: "ai", status: "idle",
                             tasks_completed_today: 5, tasks_completed_week: 20, tasks_completed_month: 60,
                             avg_resolution_minutes: 12, satisfaction_score: 4.6, quality_score: 4.8)

    get console_ai_agents_path
    assert_response :success
    assert_select ".console-stat-label", text: "Active agents"
    assert_select "td a", text: @agent.name
    assert_select ".console-card-title", text: "Performance by agent type"
  end

  test "agent show renders lifecycle stages and actions" do
    @agent.update!(lifecycle_stages: [
      { "stage_name" => "welcome", "stage_label" => "Welcome", "stage_description" => "First contact",
        "entry_trigger" => "user_registered", "automated_actions" => [], "exit_conditions" => {}, "handoff_rules" => {} }
    ])

    get console_ai_agent_path(@agent)
    assert_response :success
    assert_select ".console-onboarding-label", text: "Welcome"
    assert_select "a", text: "Add lifecycle stage"
  end

  test "stage add, edit and delete round-trip" do
    get edit_stage_console_ai_agent_path(@agent)
    assert_response :success

    patch update_stage_console_ai_agent_path(@agent), params: {
      stage_label: "Follow up", stage_name: "follow_up", stage_description: "Chase docs",
      entry_trigger: "docs_requested",
      automated_actions: [ { action_type: "send_email", email_template_id: email_templates(:verification_template).id.to_s, delay: { duration: "2", unit: "days" } } ]
    }

    @agent.reload
    stage = @agent.lifecycle_stages.last
    assert_equal "follow_up", stage["stage_name"]
    assert_equal "send_email", stage.dig("automated_actions", 0, "action_type")
    assert_equal 2, stage.dig("automated_actions", 0, "delay", "duration")

    index = @agent.lifecycle_stages.size - 1
    delete delete_stage_console_ai_agent_path(@agent, stage_index: index)
    assert_equal index, @agent.reload.lifecycle_stages.size
  end

  test "lender admins are denied" do
    sign_in users(:lender_admin_user)
    get console_ai_agents_path
    assert_redirected_to console_root_path
  end
end
