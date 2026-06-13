class AdminFinancialMetricsService
  def initialize(applications_scope: Application.all, contracts_scope: nil)
    @applications = applications_scope
    @contracts = contracts_scope || default_contracts_scope
  end

  def call
    {
      revenue: revenue_metrics,
      capital: capital_deployment,
      regional: regional_breakdown,
      distributions: distribution_metrics,
      cost_structure: cost_structure,
      recent: recent_activity
    }
  end

  def revenue_metrics
    params = EpmModelConfig.params
    fp_margin_rate = params[:fp_margin]
    aum = @contracts.sum(:allocated_amount)

    weighted_cost = weighted_cost_of_capital
    fp_margin_pct = (fp_margin_rate * 100).round(2)
    net_margin_pct = (fp_margin_pct - weighted_cost).round(2)

    origination_this_month = @applications.where(status: :accepted, updated_at: Time.current.beginning_of_month..).sum(:equity_investment_amount)
    origination_last_month = @applications.where(status: :accepted, updated_at: 1.month.ago.beginning_of_month..1.month.ago.end_of_month).sum(:equity_investment_amount)

    {
      total_aum: aum,
      fp_margin_rate: fp_margin_pct,
      retail_margin_rate: (params[:retail_margin] * 100).round(2),
      total_variable_cost_rate: (EpmModelConfig.total_variable_cost * 100).round(2),
      margin_income_annual: (aum * fp_margin_rate).round(0),
      profit_share_pct: (params[:profit_share_pct] * 100).round(0),
      profit_share_interval: params[:profit_share_interval],
      weighted_cost_of_capital: weighted_cost,
      net_margin_rate: net_margin_pct,
      net_margin_annual: (aum * net_margin_pct / 100).round(0),
      origination_this_month: origination_this_month,
      origination_last_month: origination_last_month,
      origination_trend: growth_trend(origination_this_month, origination_last_month)
    }
  end

  def capital_deployment
    pools = FunderPool.real.all
    capacity = pools.sum(:amount)
    allocated = pools.sum(:allocated)

    {
      capital_deployed: @contracts.where.not(status: :awaiting_funding).sum(:allocated_amount),
      capital_awaiting: @contracts.where(status: :awaiting_funding).sum(:allocated_amount),
      total_pool_capacity: capacity,
      total_pool_allocated: allocated,
      pool_utilisation: capacity.positive? ? (allocated.to_f / capacity * 100).round(1) : 0,
      top_pools: top_pool_chart_data
    }
  end

  def regional_breakdown
    %w[AU US NZ UK].each_with_object({}) do |region, acc|
      region_apps = @applications.where(region: region)
      region_ids = region_apps.pluck(:id)
      region_contracts = region_ids.any? ? @contracts.where(application_id: region_ids) : Contract.none

      acc[region] = {
        applications: region_apps.count,
        contracts: region_contracts.count,
        aum: region_contracts.sum(:allocated_amount),
        capital_deployed: region_contracts.where.not(status: :awaiting_funding).sum(:allocated_amount),
        avg_home_value: region_apps.average(:home_value)&.round(0) || 0,
        avg_equity_pct: region_apps.where.not(equity_percentage: nil).average(:equity_percentage)&.round(1) || 0
      }
    end
  end

  def distribution_metrics
    app_ids = @applications.pluck(:id)
    return { total: 0, this_month: 0, monthly_trend: {} } if app_ids.empty?

    completed = Distribution.where(application_id: app_ids, status: :completed)

    {
      total: completed.sum(:amount),
      this_month: completed.where(processed_at: Time.current.beginning_of_month..).sum(:amount),
      monthly_trend: monthly_distribution_trend(completed)
    }
  end

  def cost_structure
    params = EpmModelConfig.params
    {
      wholesale_margin: params[:wholesale_margin],
      retail_margin: params[:retail_margin],
      fp_margin: params[:fp_margin],
      hedging_fee: params[:hedging_fee]
    }
  end

  def recent_activity
    {
      recent_contracts: @contracts.includes(application: :user).order(created_at: :desc).limit(8),
      recent_accepted: @applications.where(status: :accepted).includes(:user).order(updated_at: :desc).limit(5)
    }
  end

  private

  def default_contracts_scope
    app_ids = @applications.pluck(:id)
    return Contract.none if app_ids.empty?
    Contract.real.where(application_id: app_ids).where(demo: false)
  end

  def weighted_cost_of_capital
    funded = @contracts.where.not(cost_of_capital_rate: nil).where.not(allocated_amount: 0)
    return 0 unless funded.any?

    total = funded.sum(:allocated_amount)
    return 0 if total.zero?

    weighted = funded.sum("cost_of_capital_rate * allocated_amount")
    (weighted / total).round(2)
  end

  def top_pool_chart_data
    FunderPool.real.includes(:wholesale_funder).order(allocated: :desc).limit(5).map do |pool|
      {
        name: pool.name.truncate(20),
        allocated: pool.allocated,
        capacity: pool.amount,
        funder: pool.wholesale_funder.name.truncate(15)
      }
    end
  end

  def monthly_distribution_trend(scope)
    scope.where(processed_at: 6.months.ago..).group_by_month(:processed_at).sum(:amount)
  rescue NoMethodError
    {}
  end

  def growth_trend(current, previous)
    return :flat if previous.zero? && current.zero?
    return :up if previous.zero? && current.positive?

    pct = ((current - previous).to_f / previous * 100).round(1)
    return :up if pct > 5
    return :down if pct < -5
    :flat
  end
end
