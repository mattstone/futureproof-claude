# Investments — the portfolio's investment-management view (Yumi's domain).
# Surfaces the borrower investment accounts, returns and income distribution
# that otherwise only appear per-contract or buried in Analytics.
class Console::InvestmentsController < Console::BaseController
  before_action -> { require_capability(:view_pipeline) }

  def show
    @balances = AdminPortfolioMetricsService.new.account_balances
    risk = AdminRiskMetricsService.new.call
    @health = risk[:portfolio_health]
    @monitoring = risk[:monitoring]
    @distributions_total = Distribution.completed_distributions.sum(:amount)
    @distributions_month = Distribution.completed_distributions
                                       .where(processed_at: Time.current.beginning_of_month..).sum(:amount)
    @top_accounts = Contract.real.where("investment_balance > 0")
                            .includes(application: :user)
                            .order(investment_balance: :desc).limit(10)
  end
end
