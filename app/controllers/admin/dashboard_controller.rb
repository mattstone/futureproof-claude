class Admin::DashboardController < Admin::BaseController
  before_action :load_dashboard_data

  def index
    # Executive summary & KPIs
    @summary = build_summary
    
    # Portfolio health
    @portfolio = build_portfolio
    
    # Performance metrics
    @performance = build_performance
    
    # Risk & alerts
    @alerts = build_alerts
    
    # Trend data (charts)
    @trends = build_trends
    
    # Top performers
    @top_performers = build_top_performers
  end

  # Webhooks management page (placeholder)
  def webhooks
    redirect_to admin_dashboard_path, notice: 'Webhooks section coming soon'
  end

  # Retry a failed webhook (placeholder)
  def retry_webhook
    redirect_to admin_dashboard_path, notice: 'Webhook retry feature coming soon'
  end

  # Toggle webhook active/inactive (placeholder)
  def toggle_webhook
    head :ok
  end

  # Applications list page (placeholder)
  def applications
    redirect_to admin_dashboard_path, notice: 'Applications section coming soon'
  end

  # Payments list page (placeholder)
  def payments
    redirect_to admin_dashboard_path, notice: 'Payments section coming soon'
  end

  private

  def load_dashboard_data
    @jurisdiction = session[:admin_jurisdiction] || "AU"
  end

  # ============================================================================
  # EXECUTIVE SUMMARY - The "at a glance" view
  # ============================================================================
  def build_summary
    {
      # Capital metrics
      total_capital_raised: FunderPool.sum(:amount),
      capital_deployed: Contract.sum(:allocated_amount),
      capital_utilization: calculate_capital_utilization,
      
      # Active business
      active_contracts: Contract.where(status: [:ok, :in_holiday]).count,
      total_applications: Application.where(status: ['submitted', 'processing', 'accepted']).count,
      
      # Financial performance
      monthly_income_generated: calculate_monthly_income,
      portfolio_pl_ytd: calculate_portfolio_pl,
      
      # Health indicators
      contracts_in_arrears: Contract.where(status: :in_arrears).count,
      lenders_active: Lender.joins(:contracts).distinct.count
    }
  end

  # ============================================================================
  # PORTFOLIO HEALTH - Breakdown by status and type
  # ============================================================================
  def build_portfolio
    {
      # Contract status distribution
      status_distribution: Contract.group(:status).count.transform_keys { |k| k.humanize },
      
      # Contracts by lender (top 5)
      top_lenders: Lender.joins(:contracts)
                          .group('lenders.id, lenders.name')
                          .select('lenders.id, lenders.name, COUNT(contracts.id) as contract_count, SUM(contracts.allocated_amount) as total_allocated')
                          .order('total_allocated DESC')
                          .limit(5)
                          .map { |l| { name: l.name, count: l.contract_count, total: l.total_allocated } },
      
      # Contracts by pool (top 5)
      top_pools: FunderPool.joins(:contracts)
                           .group('funder_pools.id, funder_pools.name')
                           .select('funder_pools.id, funder_pools.name, COUNT(contracts.id) as contract_count, SUM(contracts.allocated_amount) as total_allocated')
                           .order('total_allocated DESC')
                           .limit(5)
                           .map { |p| { name: p.name, count: p.contract_count, total: p.total_allocated } },
      
      # Wholesale funders performance
      funders_overview: WholesaleFunder.map { |f|
        {
          name: f.name,
          country: f.country,
          total_capital: f.total_capital,
          deployed: f.total_allocated,
          utilization: f.capital_allocation_percentage,
          contracts: f.funder_pools.joins(:contracts).distinct.count(:contracts)
        }
      }
    }
  end

  # ============================================================================
  # PERFORMANCE - Financial metrics and ROI
  # ============================================================================
  def build_performance
    {
      # Return metrics
      weighted_investment_return: calculate_weighted_return,
      weighted_cost_of_capital: calculate_weighted_coc,
      net_margin: calculate_net_margin,
      
      # Income metrics
      monthly_payment_volume: Contract.where(status: [:ok, :in_holiday]).sum(:monthly_payment),
      total_paid_to_date: Contract.sum(:total_payments_made),
      average_contract_value: Contract.where.not(allocated_amount: 0).average(:allocated_amount).to_i,
      
      # Age analysis
      average_contract_age_months: calculate_average_contract_age,
      contracts_by_age: contracts_by_age_group
    }
  end

  # ============================================================================
  # RISK & ALERTS - What needs attention right now
  # ============================================================================
  def build_alerts
    alerts = []
    
    # 1. Contracts in arrears
    arrears_contracts = Contract.where(status: :in_arrears).includes(:application, :lender)
    if arrears_contracts.any?
      alerts << {
        type: :critical,
        icon: '🚨',
        title: "#{arrears_contracts.count} Contracts in Arrears",
        description: "Immediate action required on overdue payments",
        action_url: '#',
        contracts: arrears_contracts.map { |c| {
          id: c.id,
          lender: c.lender&.name,
          amount: c.allocated_amount,
          status: c.status
        }}
      }
    end
    
    # 2. Applications pending approval (> 7 days)
    old_pending = Application.where(status: 'processing')
                              .where('updated_at < ?', 7.days.ago)
                              .count
    if old_pending > 0
      alerts << {
        type: :warning,
        icon: '⏱️',
        title: "#{old_pending} Applications Pending >7 Days",
        description: "Old processing applications need review/approval",
        action_url: '#',
        count: old_pending
      }
    end
    
    # 3. Low pool utilization
    underutilized_pools = FunderPool.where('(allocated / amount) < ?', 0.3)
    if underutilized_pools.any?
      alerts << {
        type: :info,
        icon: '💡',
        title: "#{underutilized_pools.count} Pools Underutilized",
        description: "Capital available for deployment",
        action_url: '#',
        pools: underutilized_pools.map { |p| { name: p.name, utilization: (p.allocated / p.amount * 100).round(1) } }
      }
    end
    
    # 4. Upcoming contract maturity (next 30 days)
    maturing_soon = Contract.where('end_date IS NOT NULL AND end_date BETWEEN ? AND ?', Date.today, 30.days.from_now)
    if maturing_soon.any?
      alerts << {
        type: :warning,
        icon: '📅',
        title: "#{maturing_soon.count} Contracts Mature in 30 Days",
        description: "Plan for contract renewals or closures",
        action_url: '#',
        count: maturing_soon.count
      }
    end
    
    alerts
  end

  # ============================================================================
  # TRENDS - Historical performance & projections
  # ============================================================================
  def build_trends
    {
      # Monthly capital deployment (last 12 months)
      monthly_deployment: generate_monthly_deployment_data,
      
      # Monthly P&L trend
      monthly_pl: generate_monthly_pl_data,
      
      # Portfolio growth
      portfolio_growth: generate_portfolio_growth_data,
      
      # Contract health trend
      contract_health_trend: generate_contract_health_trend
    }
  end

  # ============================================================================
  # TOP PERFORMERS - What's working well
  # ============================================================================
  def build_top_performers
    {
      # Best performing lenders (by ROI)
      top_lenders: Lender.joins(:contracts)
                         .select('lenders.*, AVG(contracts.investment_return_rate) as avg_return')
                         .group('lenders.id')
                         .order('avg_return DESC')
                         .limit(3)
                         .map { |l| {
                           name: l.name,
                           contracts: l.contracts.count,
                           avg_return: l.avg_return.round(1),
                           total_deployed: l.contracts.sum(:allocated_amount)
                         }},
      
      # Best performing pools
      top_pools: FunderPool.joins(:contracts)
                           .select('funder_pools.*, AVG(contracts.investment_return_rate) as avg_return')
                           .group('funder_pools.id')
                           .order('avg_return DESC')
                           .limit(3)
                           .map { |p| {
                             name: p.name,
                             contracts: p.contracts.count,
                             avg_return: p.avg_return.round(1),
                             total_deployed: p.contracts.sum(:allocated_amount)
                           }},
      
      # Best performing contracts (highest ROI)
      top_contracts: Contract.where.not(investment_return_rate: nil)
                             .order(investment_return_rate: :desc)
                             .limit(5)
                             .map { |c| {
                               id: c.id,
                               lender: c.lender&.name,
                               return_rate: c.investment_return_rate.round(1),
                               allocated: c.allocated_amount,
                               status: c.status
                             }}
    }
  end

  # ============================================================================
  # CALCULATION HELPERS
  # ============================================================================

  def calculate_capital_utilization
    total = FunderPool.sum(:amount)
    deployed = Contract.sum(:allocated_amount)
    return 0 if total == 0
    ((deployed / total) * 100).round(1)
  end

  def calculate_monthly_income
    Contract.where(status: [:ok, :in_holiday]).sum(:monthly_payment).to_f
  end

  def calculate_portfolio_pl
    active_contracts = Contract.where(status: [:ok, :in_holiday])
    pl = 0
    active_contracts.each do |c|
      months_active = c.start_date ? [(Date.today - c.start_date).to_i / 30.0, 0].max : 0
      inv_return = c.investment_balance.to_f * (c.investment_return_rate.to_f / 100.0)
      coc = c.allocated_amount.to_f * (c.cost_of_capital_rate.to_f / 100.0) * (months_active / 12.0)
      monthly_cost = c.monthly_payment.to_f
      pl += (inv_return - monthly_cost - coc)
    end
    pl.round(2)
  end

  def calculate_weighted_return
    total_investment = Contract.where('investment_balance > 0').sum(:investment_balance)
    return 0 if total_investment == 0
    weighted = Contract.where('investment_balance > 0')
                       .sum('investment_balance * investment_return_rate')
    (weighted / total_investment).round(2)
  end

  def calculate_weighted_coc
    total_allocated = Contract.sum(:allocated_amount)
    return 0 if total_allocated == 0
    weighted = Contract.sum('allocated_amount * cost_of_capital_rate')
    (weighted / total_allocated).round(2)
  end

  def calculate_net_margin
    calculate_weighted_return - calculate_weighted_coc
  end

  def calculate_average_contract_age
    active = Contract.where.not(start_date: nil)
    return 0 if active.empty?
    total_days = active.sum { |c| (Date.today - c.start_date).to_i }
    (total_days / active.count / 30.0).round(1)
  end

  def contracts_by_age_group
    active = Contract.where.not(start_date: nil)
    {
      new: active.where('start_date > ?', 3.months.ago).count,
      growing: active.where('start_date BETWEEN ? AND ?', 3.months.ago, 12.months.ago).count,
      mature: active.where('start_date < ?', 12.months.ago).count
    }
  end

  def generate_monthly_deployment_data
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      deployed = Contract.where('start_date BETWEEN ? AND ?', month_start, month_end).sum(:allocated_amount)
      data[month_name] = deployed
    end
    data.reverse_each.to_h
  end

  def generate_monthly_pl_data
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      # Simplified: sum monthly payments for active contracts during that month
      monthly_pl = Contract.where('start_date <= ? AND (end_date IS NULL OR end_date >= ?)', month_end, month_start)
                           .where(status: [:ok, :in_holiday])
                           .sum(:monthly_payment)
      data[month_name] = monthly_pl
    end
    data.reverse_each.to_h
  end

  def generate_portfolio_growth_data
    data = {}
    cumulative = 0
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %y')
      deployed_this_month = Contract.where('start_date BETWEEN ? AND ?', month_start, month_end).sum(:allocated_amount)
      cumulative += deployed_this_month
      data[month_name] = cumulative
    end
    data.reverse_each.to_h
  end

  def generate_contract_health_trend
    {
      ok: Contract.where(status: :ok).count,
      in_holiday: Contract.where(status: :in_holiday).count,
      in_arrears: Contract.where(status: :in_arrears).count,
      complete: Contract.where(status: :complete).count,
      awaiting: Contract.where(status: :awaiting_funding).count
    }
  end
end
