class AdminPortfolioMetricsService
  def initialize(applications_scope: Application.all, contracts_scope: Contract.real.all, users_scope: User.all)
    @applications = applications_scope
    @contracts = contracts_scope
    @users = users_scope
  end

  def top_line
    distributions = Distribution.where(application_id: @applications.pluck(:id)) if @applications.any?
    distributions ||= Distribution.none

    {
      total_applications: @applications.count,
      total_capital_deployed: @applications.sum(:equity_investment_amount),
      active_investments: @applications.where(status: :accepted).count,
      total_distributions: distributions.sum(:amount),
      pending_applications: @applications.where(status: :submitted).count,
      approved_applications: @applications.where(status: :accepted).count,
      rejected_applications: @applications.where(status: :rejected).count,
      applications_by_region: @applications.group(:region).count,
      capital_by_region: @applications.group(:region).sum(:equity_investment_amount)
    }
  end

  def capital_overview
    raised = FunderPool.real.sum(:amount)
    deployed = Contract.real.sum(:allocated_amount)
    weighted = FunderPool.real.sum("amount * (benchmark_rate + margin_rate)")

    {
      total_capital_raised: raised,
      capital_deployed: deployed,
      capital_available: raised - deployed,
      capital_utilisation: raised.positive? ? ((deployed / raised) * 100).round(1) : 0,
      wacc: raised.positive? ? (weighted / raised).round(2) : 0
    }
  end

  def contract_summary
    {
      total_contracts: Contract.real.count,
      active_contracts: Contract.real.where(status: %i[ok in_holiday]).count,
      in_holiday_contracts: Contract.real.where(status: :in_holiday).count,
      awaiting_funding_contracts: Contract.real.where(status: :awaiting_funding).count,
      total_monthly_outflows: Contract.real.where(status: %i[ok in_holiday]).sum(:monthly_payment),
      portfolio_pl: Contract.real.includes(:application).sum { |c| self.class.contract_net_pl(c) }
    }
  end

  def account_balances
    offset = @contracts.sum(:offset_balance)
    investment = @contracts.sum(:investment_balance)
    invested = @contracts.where("investment_balance > 0").sum(:investment_balance)
    weighted_return = @contracts.where("investment_balance > 0").sum("investment_balance * investment_return_rate")

    {
      total_offset: offset,
      total_investment: investment,
      total_account_value: offset + investment,
      avg_investment_return: invested.positive? ? (weighted_return / invested).round(2) : 0
    }
  end

  def pool_chart_data(limit: 8)
    FunderPool.real.includes(:wholesale_funder).order(allocated: :desc).limit(limit).map do |pool|
      {
        name: pool.name.truncate(20),
        allocated: pool.allocated,
        capacity: pool.amount,
        funder: pool.wholesale_funder.name.truncate(15)
      }
    end
  end

  def funder_breakdown_data
    WholesaleFunder.includes(:funder_pools).map do |funder|
      committed = funder.funder_pools.sum(&:amount)
      deployed = funder.funder_pools.sum(&:allocated)
      {
        name: funder.name.truncate(20),
        committed: committed,
        deployed: deployed,
        utilisation: committed.positive? ? ((deployed.to_f / committed) * 100).round(1) : 0
      }
    end
  end

  def pool_allocation_data
    FunderPool.real.includes(:wholesale_funder).map do |pool|
      {
        name: pool.display_name,
        allocated: pool.allocated,
        available: pool.available_amount,
        total: pool.amount,
        utilization: pool.allocation_percentage
      }
    end
  end

  def pool_utilization_data
    allocated = FunderPool.real.sum(:allocated)
    capacity = FunderPool.real.sum(:amount)
    [
      { label: "Allocated", value: allocated, color: "#dc2626" },
      { label: "Available", value: capacity - allocated, color: "#059669" }
    ]
  end

  def monthly_pl(months: 24)
    data = {}
    cumulative = 0
    contracts = Contract.real.where.not(status: :awaiting_funding).where("start_date <= ?", Date.today)

    months.times do |i|
      month_date = (months - 1 - i).months.ago.beginning_of_month.to_date
      month_end = month_date.end_of_month
      active = contracts.where("start_date <= ?", month_end)
      monthly_pl = active.sum { |c| monthly_pl_for_contract(c, month_end) }
      cumulative += monthly_pl
      data[month_date.strftime("%b %Y")] = { monthly: monthly_pl.round(0), cumulative: cumulative.round(0) }
    end
    data
  end

  def growth_data(scope:, months: 6)
    each_month(months) do |month_start, month_end|
      scope.where(created_at: month_start..month_end).count
    end
  end

  def conversion_data(months: 6)
    each_month(months) do |month_start, month_end|
      users_created = @users.where(created_at: month_start..month_end).count
      submitted = @applications.joins(:user)
                               .where(users: { created_at: month_start..month_end })
                               .where(status: %w[submitted processing accepted rejected])
                               .count
      users_created.positive? ? ((submitted.to_f / users_created) * 100).round(1) : 0
    end
  end

  def monthly_fum(months: 6)
    each_month(months) do |month_start, month_end|
      @contracts.joins(:application)
                .where(contracts: { created_at: month_start..month_end })
                .where(applications: { home_value: 0.. })
                .sum("applications.home_value")
    end
  end

  def cumulative_fum(months: 6)
    data = {}
    months.times do |i|
      month_end = i.months.ago.end_of_month
      month_name = month_end.strftime("%b %Y")
      data[month_name] = @contracts.joins(:application)
                                   .where("contracts.created_at <= ?", month_end)
                                   .where(applications: { home_value: 0.. })
                                   .sum("applications.home_value")
    end
    data.reverse_each.to_h
  end

  def self.contract_net_pl(contract)
    months_active = contract.start_date ? [ (Date.today - contract.start_date).to_i / 30.0, 0 ].max : 0
    investment_gain = contract.investment_balance.to_f * (contract.investment_return_rate.to_f / 100.0)
    cost_of_capital = contract.allocated_amount.to_f * (contract.cost_of_capital_rate.to_f / 100.0) * (months_active / 12.0)
    investment_gain - contract.total_payments_made.to_f - cost_of_capital
  end

  private

  def each_month(months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      data[month_start.strftime("%b %Y")] = yield(month_start, month_end)
    end
    data.reverse_each.to_h
  end

  def monthly_pl_for_contract(contract, month_end)
    months_active = [ (month_end - contract.start_date).to_i / 30.0, 0 ].max
    inv_gain_monthly = contract.investment_balance.to_f * (contract.investment_return_rate.to_f / 100.0) / [ months_active, 1 ].max
    cost_monthly = contract.allocated_amount.to_f * (contract.cost_of_capital_rate.to_f / 100.0) / 12.0
    inv_gain_monthly - contract.monthly_payment.to_f - cost_monthly
  end
end
