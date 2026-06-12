require "test_helper"

class Console::PortfolioTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  # --- Contracts -------------------------------------------------------------

  test "contracts index filters by status and searches by id" do
    contract = contracts(:active_contract)

    get console_contracts_path
    assert_response :success
    assert_select "td a", text: "##{contract.id}"

    get console_contracts_path(status: "awaiting_funding")
    assert_select "td a", { text: "##{contract.id}", count: 0 }

    get console_contracts_path(search: contract.id.to_s)
    assert_select "td a", text: "##{contract.id}"
  end

  test "contract show renders details, related records and history" do
    contract = contracts(:active_contract)
    get console_contract_path(contract)

    assert_response :success
    assert_select ".console-card-title", text: "Contract details"
    assert_select ".console-related-item", text: /Application ##{contract.application_id}/
    assert_select ".console-history-title"
  end

  test "viewing a contract logs an audit version" do
    contract = contracts(:active_contract)
    assert_difference -> { contract.contract_versions.count } do
      get console_contract_path(contract)
    end
  end

  test "contract update records the change" do
    contract = contracts(:active_contract)
    patch console_contract_path(contract), params: {
      contract: { status: "in_holiday", start_date: contract.start_date, end_date: contract.end_date }
    }

    assert_redirected_to console_contract_path(contract)
    assert_equal "in_holiday", contract.reload.status
  end

  test "contract message draft and send flows" do
    contract = contracts(:active_contract)
    agent = AiAgent.first

    assert_difference -> { contract.contract_messages.count } do
      post create_message_console_contract_path(contract), params: {
        contract_message: { subject: "Update", content: "Your investment is performing well.", ai_agent_id: agent&.id }
      }
    end
    draft = contract.contract_messages.order(:created_at).last
    assert draft.draft?

    patch send_message_console_contract_path(contract, message_id: draft.id)
    assert draft.reload.sent?
  end

  test "lender admin cannot reach other lenders' contracts" do
    sign_in users(:lender_admin_user)
    get console_contract_path(contracts(:active_contract))
    assert_response :not_found
  end

  # --- Cohorts -----------------------------------------------------------------

  test "cohorts render heatmap data and table" do
    get console_cohorts_path
    assert_response :success
    assert_select "[data-controller='cohort-heatmap']"
    assert_select "td", text: /Q[1-4]/
  end

  # --- Analytics ------------------------------------------------------------------

  test "analytics renders gauges, charts and overview cards" do
    get console_analytics_path

    assert_response :success
    assert_select ".console-gauge", count: 4
    assert_select "[data-controller='application-funnel']"
    assert_select "[data-controller='calendar-heatmap']"
    assert_select "[data-controller='regional-choropleth']"
    assert_select "[data-controller='time-series-chart']", count: 3
    assert_select ".console-card-title", text: "Financial"
    assert_select ".console-card-title", text: "Risk & investment health"
  end

  test "analytics respects the jurisdiction switcher" do
    post console_set_jurisdiction_path, params: { jurisdiction: "UK" }
    get console_analytics_path
    assert_response :success
    assert_match(/UK/, response.body)
  end
end
