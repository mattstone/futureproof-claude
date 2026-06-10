require "test_helper"

class AdminFinancialMetricsServiceTest < ActiveSupport::TestCase
  setup do
    @service = AdminFinancialMetricsService.new
  end

  test "call returns all six sections" do
    result = @service.call

    assert result.key?(:revenue)
    assert result.key?(:capital)
    assert result.key?(:regional)
    assert result.key?(:distributions)
    assert result.key?(:cost_structure)
    assert result.key?(:recent)
  end

  test "revenue_metrics computes margin and net margin" do
    result = @service.revenue_metrics

    assert_kind_of Numeric, result[:fp_margin_rate]
    assert_kind_of Numeric, result[:net_margin_rate]
    assert_kind_of Numeric, result[:weighted_cost_of_capital]
    assert_kind_of Numeric, result[:margin_income_annual]
    assert_includes %i[up down flat], result[:origination_trend]
  end

  test "capital_deployment includes pool utilisation" do
    result = @service.capital_deployment

    assert_kind_of Numeric, result[:capital_deployed]
    assert_kind_of Numeric, result[:capital_awaiting]
    assert_kind_of Numeric, result[:pool_utilisation]
    assert_kind_of Array, result[:top_pools]
  end

  test "regional_breakdown returns entries for all four regions" do
    result = @service.regional_breakdown

    %w[AU US NZ UK].each do |region|
      assert result.key?(region)
      assert result[region].key?(:applications)
      assert result[region].key?(:aum)
    end
  end

  test "distribution_metrics handles empty application scope" do
    result = AdminFinancialMetricsService.new(applications_scope: Application.none).distribution_metrics

    assert_equal 0, result[:total]
    assert_equal 0, result[:this_month]
    assert_equal({}, result[:monthly_trend])
  end

  test "cost_structure returns the four model parameters" do
    result = @service.cost_structure

    %i[wholesale_margin retail_margin fp_margin hedging_fee].each do |key|
      assert result.key?(key)
    end
  end

  test "recent_activity returns most recent contracts and acceptances" do
    result = @service.recent_activity

    assert_respond_to result[:recent_contracts], :each
    assert_respond_to result[:recent_accepted], :each
  end
end
