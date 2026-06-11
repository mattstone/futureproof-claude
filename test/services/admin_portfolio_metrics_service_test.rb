require "test_helper"

class AdminPortfolioMetricsServiceTest < ActiveSupport::TestCase
  setup do
    @service = AdminPortfolioMetricsService.new
  end

  test "top_line returns counts and aggregates without raising" do
    result = @service.top_line

    assert_equal Application.count, result[:total_applications]
    assert_kind_of Hash, result[:applications_by_region]
    assert_kind_of Hash, result[:capital_by_region]
    assert_operator result[:total_capital_deployed], :>=, 0
  end

  test "capital_overview computes utilisation and WACC" do
    result = @service.capital_overview

    raised = FunderPool.sum(:amount)
    deployed = Contract.sum(:allocated_amount)
    assert_equal raised, result[:total_capital_raised]
    assert_equal deployed, result[:capital_deployed]
    assert_equal raised - deployed, result[:capital_available]
    assert_kind_of Numeric, result[:capital_utilisation]
    assert_kind_of Numeric, result[:wacc]
  end

  test "contract_summary returns counts by status" do
    result = @service.contract_summary

    assert_equal Contract.count, result[:total_contracts]
    assert_equal Contract.where(status: %i[ok in_holiday]).count, result[:active_contracts]
    assert_equal Contract.where(status: :awaiting_funding).count, result[:awaiting_funding_contracts]
  end

  test "account_balances aggregates offset and investment" do
    result = @service.account_balances

    assert_equal Contract.sum(:offset_balance), result[:total_offset]
    assert_equal Contract.sum(:investment_balance), result[:total_investment]
    assert_equal result[:total_offset] + result[:total_investment], result[:total_account_value]
  end

  test "pool_chart_data returns at most the limit" do
    result = @service.pool_chart_data(limit: 1)

    assert_operator result.size, :<=, 1
  end

  test "pool_utilization_data totals match FunderPool sums" do
    result = @service.pool_utilization_data

    assert_equal 2, result.size
    assert_equal FunderPool.sum(:allocated), result[0][:value]
    assert_equal FunderPool.sum(:amount) - FunderPool.sum(:allocated), result[1][:value]
  end

  test "monthly_pl returns one entry per month" do
    result = @service.monthly_pl(months: 6)

    assert_equal 6, result.size
    result.each_value do |v|
      assert v.key?(:monthly)
      assert v.key?(:cumulative)
    end
  end

  test "growth_data returns one count per month, oldest first" do
    result = @service.growth_data(scope: Application.all, months: 3)

    assert_equal 3, result.size
    assert_equal result.values.sum, Application.where('created_at >= ?', 3.months.ago.beginning_of_month).count
  end

  test "conversion_data returns rate per month" do
    result = @service.conversion_data(months: 3)

    assert_equal 3, result.size
    result.each_value { |v| assert_kind_of Numeric, v }
  end

  test "monthly_fum and cumulative_fum return data per month" do
    monthly = @service.monthly_fum(months: 3)
    cumulative = @service.cumulative_fum(months: 3)

    assert_equal 3, monthly.size
    assert_equal 3, cumulative.size
  end

  test "contract_net_pl is callable as a class method" do
    contract = contracts(:active_contract)
    contract.update!(
      investment_balance: 100_000,
      investment_return_rate: 5.0,
      allocated_amount: 500_000,
      cost_of_capital_rate: 4.0,
      total_payments_made: 1_000,
      start_date: 1.year.ago.to_date
    )

    pl = AdminPortfolioMetricsService.contract_net_pl(contract)
    assert_kind_of Numeric, pl
  end
end
