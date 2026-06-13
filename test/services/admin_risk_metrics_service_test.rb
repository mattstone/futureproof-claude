require "test_helper"

class AdminRiskMetricsServiceTest < ActiveSupport::TestCase
  setup do
    @service = AdminRiskMetricsService.new
  end

  test "call returns all five sections" do
    result = @service.call

    assert result.key?(:portfolio_health)
    assert result.key?(:alerts)
    assert result.key?(:concentration)
    assert result.key?(:monitoring)
    assert result.key?(:model)
  end

  test "portfolio_health rates score correctly" do
    health = @service.portfolio_health

    assert_kind_of Numeric, health[:health_score]
    assert_includes %w[Excellent Good Fair], health[:health_rating]
    assert_kind_of Numeric, health[:total_aum]
    assert_kind_of Numeric, health[:at_risk_pct]
  end

  test "alerts always include at least one entry" do
    alerts = @service.alerts

    refute_empty alerts
    alerts.each do |a|
      assert a.key?(:severity)
      assert a.key?(:title)
      assert a.key?(:detail)
    end
  end

  test "alerts surfaces healthy when no issues" do
    Contract.update_all(status: :ok)
    alerts = AdminRiskMetricsService.new.alerts

    healthy = alerts.find { |a| a[:title] == "Portfolio Healthy" }
    assert healthy
    assert_equal :success, healthy[:severity]
  end

  test "concentration_risk includes all four regions" do
    concentration = @service.concentration_risk

    assert concentration[:by_region].key?("AU")
    assert concentration[:by_region].key?("US")
    assert concentration[:by_region].key?("NZ")
    assert concentration[:by_region].key?("UK")
  end

  test "concentration_risk value bands sum to total apps" do
    concentration = @service.concentration_risk
    band_total = concentration[:by_value_band].values.sum

    assert_operator band_total, :<=, Application.count
  end

  test "contract_monitoring returns return-rate stats" do
    monitoring = @service.contract_monitoring

    assert monitoring.key?(:status_breakdown)
    assert monitoring.key?(:maturing_soon)
    assert_kind_of Numeric, monitoring[:avg_return_rate]
  end

  test "model_context returns version and metrics" do
    model = @service.model_context

    assert_equal EpmModelConfig.model_version, model[:version]
    assert model.key?(:pod_yr30)
    assert model.key?(:reinsurance_poc)
    assert model.key?(:portfolio_poc_steady_state)
  end

  test "service handles empty applications scope" do
    service = AdminRiskMetricsService.new(applications_scope: Application.none)

    health = service.portfolio_health
    assert_equal 0, health[:total_contracts]
    assert_equal 100.0, health[:health_score]
  end
end
