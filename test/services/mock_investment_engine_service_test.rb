require "test_helper"

class MockInvestmentEngineServiceTest < ActiveSupport::TestCase
  setup do
    MockInvestmentEngineService.set_scenario(:normal)
  end

  test "check_funding_availability returns expected keys" do
    result = MockInvestmentEngineService.check_funding_availability(funder_pool_id: 1, amount: 1_000_000)
    %i[available pool_balance amount_requested approval_likelihood conditions expected_return_rate].each { |k| assert result.key?(k), "Missing: #{k}" }
    assert_equal true, result[:available]
    assert_equal 1_000_000, result[:amount_requested]
  end

  test "no_funding scenario" do
    MockInvestmentEngineService.set_scenario(:no_funding)
    result = MockInvestmentEngineService.check_funding_availability(funder_pool_id: 1, amount: 1_000_000)
    assert_equal false, result[:available]
  end

  test "request_capital_allocation returns expected keys" do
    result = MockInvestmentEngineService.request_capital_allocation(funder_pool_id: 1, contract_id: 42, amount: 800_000)
    %i[allocation_id status amount].each { |k| assert result.key?(k), "Missing: #{k}" }
    assert_equal "approved", result[:status]
    assert result[:allocation_id].start_with?("ALLOC-")
  end

  test "request_capital_allocation rejected when no_funding" do
    MockInvestmentEngineService.set_scenario(:no_funding)
    result = MockInvestmentEngineService.request_capital_allocation(funder_pool_id: 1, contract_id: 42, amount: 800_000)
    assert_equal "rejected", result[:status]
  end

  test "calculate_returns returns expected keys" do
    result = MockInvestmentEngineService.calculate_returns(allocation_id: "ALLOC-123456")
    %i[allocation_id period_months principal interest_rate projected_return actual_return performance_ratio].each { |k| assert result.key?(k), "Missing: #{k}" }
  end

  test "get_portfolio_summary returns expected keys" do
    result = MockInvestmentEngineService.get_portfolio_summary(1)
    %i[funder_pool_id total_capital deployed_capital available_capital active_contracts average_return_rate portfolio_health].each { |k| assert result.key?(k), "Missing: #{k}" }
  end

  test "is deterministic" do
    a = MockInvestmentEngineService.check_funding_availability(funder_pool_id: 1, amount: 500_000)
    b = MockInvestmentEngineService.check_funding_availability(funder_pool_id: 1, amount: 500_000)
    assert_equal a[:pool_balance], b[:pool_balance]
    assert_equal a[:expected_return_rate], b[:expected_return_rate]
  end
end
