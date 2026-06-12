require "test_helper"

class DemoDataFlagTest < ActiveSupport::TestCase
  test "demo contracts are excluded from the real scope and metrics" do
    contract = contracts(:active_contract)
    demo = Contract.create!(
      application: applications(:processing_application),
      demo: true,
      status: :ok,
      start_date: Date.current,
      end_date: Date.current + 25.years,
      allocated_amount: 500_000
    )

    assert_includes Contract.real, contract
    assert_not_includes Contract.real, demo

    health = AdminRiskMetricsService.new.portfolio_health
    # the demo contract's $500k must not be in AUM
    assert_equal Contract.real.sum(:allocated_amount).to_f, health[:total_aum].to_f
  end
end
