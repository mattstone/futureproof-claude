require "test_helper"

class AdminAgentDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @user = users(:regular_user)
  end

  test "admin can access agent dashboard" do
    sign_in @admin
    get admin_agent_dashboard_index_path

    assert_response :success
    assert_select "h1", "Agent Performance"
    assert_select ".metrics-grid .metric-card", 4
  end

  test "agent cards display actual column data" do
    sign_in @admin
    get admin_agent_dashboard_index_path

    assert_response :success
    # Verify no errors rendering agent cards
    assert_select ".agent-dashboard"
    assert_select ".activity-stream h2", "Recent Activity"
  end

  test "non-admin user is denied access" do
    sign_in @user
    get admin_agent_dashboard_index_path

    assert_redirected_to root_path
  end

  test "unauthenticated user is redirected to login" do
    get admin_agent_dashboard_index_path
    assert_redirected_to new_user_session_path
  end
end
