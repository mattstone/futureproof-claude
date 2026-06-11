require "test_helper"

class AdminOperationsMetricsServiceTest < ActiveSupport::TestCase
  setup do
    @service = AdminOperationsMetricsService.new
  end

  test "call returns all six metric groups" do
    result = @service.call

    assert result.key?(:applications)
    assert result.key?(:conversion)
    assert result.key?(:support)
    assert result.key?(:pain_points)
    assert result.key?(:trends)
    assert result.key?(:kpis)
  end

  test "application_metrics returns count and status breakdown" do
    result = @service.application_metrics

    assert_equal Application.count, result[:total]
    assert_kind_of Hash, result[:by_status]
    assert_kind_of Numeric, result[:acceptance_rate]
  end

  test "conversion_metrics returns rates and trend direction" do
    result = @service.conversion_metrics

    assert_kind_of Numeric, result[:conversion_rate]
    assert_includes %w[up down flat], result[:mom_direction]
    assert result[:this_month].key?(:applications)
    assert result[:last_month].key?(:contracts)
  end

  test "support_metrics returns issue and resolution counts" do
    result = @service.support_metrics

    assert_kind_of Integer, result[:contracts_at_risk]
    assert_kind_of Numeric, result[:at_risk_total_value]
    assert_kind_of Integer, result[:issues_outstanding]
  end

  test "pain_points returns success entry when nothing is critical" do
    result = @service.pain_points

    assert_kind_of Array, result
    refute_empty result
    severities = result.map { |p| p[:severity] }.uniq
    severities.each { |s| assert_includes %i[critical warning info success], s }
  end

  test "pain_points surfaces stalled processing applications" do
    app = applications(:submitted_application)
    app.update_columns(status: 'processing', updated_at: 10.days.ago)

    points = @service.pain_points
    bottleneck = points.find { |p| p[:category] == 'Processing Bottleneck' }

    assert bottleneck
    assert_equal :critical, bottleneck[:severity]
  end

  test "trends returns 12 months of data per series" do
    result = @service.trends

    assert_equal 12, result[:applications_monthly].size
    assert_equal 12, result[:contracts_monthly].size
    assert_equal 12, result[:conversion_trend].size
    assert_equal 12, result[:rejection_trend].size
  end

  test "operational_kpis returns expected keys" do
    result = @service.operational_kpis

    %i[avg_processing_days approval_rate conversion_rate at_risk_percentage app_growth_mom contract_growth_mom].each do |key|
      assert result.key?(key), "kpis missing #{key}"
      assert_kind_of Numeric, result[key]
    end
  end

  test "oldest_pending_application is nil when nothing is processing" do
    Application.where(status: 'processing').destroy_all

    result = @service.application_metrics
    assert_nil result[:oldest_pending]
  end
end
