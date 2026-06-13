require "test_helper"

class Console::AnalyticsBreadthTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  test "analytics surfaces the full portfolio / capital / risk breadth" do
    get console_analytics_path
    assert_response :success

    # New cards restored from the legacy dashboard
    assert_select ".console-card-title", text: "Portfolio"
    assert_select ".console-card-title", text: "Capital & pools"
    assert_select ".console-card-title", text: "Contract status"
    assert_select ".console-card-title", text: "Distributions"
    assert_select ".console-card-title", text: "Concentration risk"
    assert_select ".console-card-title", text: "EPM model"
    assert_select ".console-card-title", text: "Maturity watch & at-risk"
  end

  test "portfolio and capital figures render" do
    get console_analytics_path
    assert_select ".console-dl-term", text: "Active investments"
    assert_select ".console-dl-term", text: "Awaiting funding"
    assert_select ".console-dl-term", text: "Avg investment return"
    assert_select ".console-dl-term", text: "Monthly income out"
  end

  test "EPM model context shows the version" do
    get console_analytics_path
    assert_match EpmModelConfig.model_version, response.body
    assert_select ".console-dl-term", text: "PoD (30yr)"
  end

  test "maturity watch lists maturing contracts when present" do
    contract = Contract.real.first
    if contract
      contract.update_columns(status: Contract.statuses[:ok], end_date: 3.months.from_now.to_date)
      get console_analytics_path
      assert_select ".console-card-subtitle", text: "Maturing soonest"
      assert_select "a[href=?]", console_contract_path(contract)
    else
      get console_analytics_path
      assert_response :success
    end
  end

  test "presenter exposes every restored dataset key" do
    data = Console::AnalyticsPresenter.new(
      applications_scope: Application.all,
      contracts_scope: Contract.real.all,
      users_scope: User.all
    ).call

    %i[portfolio_summary contract_status account_balances capital_deployment
       distributions concentration monitoring model_context].each do |key|
      assert data.key?(key), "presenter missing #{key}"
    end
  end
end
