# Investments — the portfolio's investment-management view (Yumi's domain).
# Surfaces the borrower investment accounts, returns and income distribution
# that otherwise only appear per-contract or buried in Analytics.
class Console::InvestmentsController < Console::BaseController
  before_action -> { require_capability(:view_pipeline) }

  def show
    apps = scope_by_jurisdiction(scoped_applications, :region)
    app_ids = apps.pluck(:id)
    contracts = app_ids.any? ? Contract.real.where(application_id: app_ids) : Contract.none

    @balances = AdminPortfolioMetricsService.new(contracts_scope: contracts).account_balances
    risk = AdminRiskMetricsService.new(applications_scope: apps, contracts_scope: contracts).call
    @health = risk[:portfolio_health]
    @monitoring = risk[:monitoring]

    distributions = Distribution.completed_distributions.where(application_id: app_ids)
    @distributions_total = distributions.sum(:amount)
    @distributions_month = distributions.where(processed_at: Time.current.beginning_of_month..).sum(:amount)
    @top_accounts = contracts.where("investment_balance > 0")
                             .includes(application: :user)
                             .order(investment_balance: :desc).limit(10)
  end
end
