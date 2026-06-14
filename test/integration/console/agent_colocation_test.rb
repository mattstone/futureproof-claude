require "test_helper"

class Console::AgentColocationTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin_user) }

  # --- Agents surfaced in their functional area ------------------------------------

  test "the acquisition agent's operations appear on the pipeline page" do
    agent = ai_agents(:akane) # agent_type: applications
    get console_applications_path
    assert_response :success
    assert_select ".console-card-title", text: /#{Regexp.escape(agent.name)}/
    assert_select "a[href=?]", console_ai_agent_path(agent), text: /Configure/
    assert_select ".console-stat-label", text: "Approval rate"
  end

  test "the back-office agent's operations appear on the contracts page" do
    agent = ai_agents(:rie) # agent_type: backoffice
    get console_contracts_path
    assert_response :success
    assert_select "a[href=?]", console_ai_agent_path(agent), text: /Configure/
  end

  test "configuration still links back to Development (Agent configuration)" do
    get console_applications_path
    # The in-area panel's Configure link points at the centralised config page.
    assert_select "a[href^='/console/ai_agents/']", text: /Configure/
  end

  # --- Investments (Finance) -------------------------------------------------------

  test "the Investments page renders portfolio investment performance" do
    get console_investments_path
    assert_response :success
    assert_select ".console-page-title", text: "Investments"
    assert_select ".console-stat-label", text: "Total invested"
    assert_select ".console-stat-label", text: "Weighted avg return"
    assert_select ".console-card-title", text: "Returns & income"
    assert_select ".console-card-title", text: "Largest investment accounts"
    assert_select ".console-card-title", text: "Investment at risk"
  end

  test "the investment agent appears on the Investments page" do
    agent = ai_agents(:yumi) # agent_type: investment
    get console_investments_path
    assert_select "a[href=?]", console_ai_agent_path(agent), text: /Configure/
  end

  test "Investments is reachable from the Finance nav group" do
    get console_root_path
    assert_select "a.console-nav-link[href=?]", console_investments_path, text: /Investments/
  end
end
