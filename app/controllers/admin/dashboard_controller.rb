class Admin::DashboardController < Admin::BaseController
  def index
    # Get scoped data based on admin type
    users_scope = scoped_users
    applications_scope = scoped_applications

    # === Priority Inbox — Needs Attention ===
    @attention_items = build_attention_items(applications_scope)

    # === Agent Performance ===
    @agent_performance = build_agent_performance

    # === Agent Status Cards ===
    @agents_with_stats = build_agent_cards
    
    # User statistics
    @total_users = users_scope.count
    @active_users = users_scope.where.not(confirmed_at: nil).count
    @pending_users = users_scope.where(confirmed_at: nil).count
    @admin_users = users_scope.where(admin: true).count
    @new_users_this_month = users_scope.where('created_at >= ?', 1.month.ago).count
    
    # Application statistics
    @total_applications = applications_scope.count
    @submitted_applications = applications_scope.where(status: ['submitted', 'processing', 'accepted', 'rejected']).count
    @draft_applications = applications_scope.where(status: ['created', 'user_details', 'property_details', 'income_and_loan_options']).count
    @accepted_applications = applications_scope.where(status: 'accepted').count
    @rejected_applications = applications_scope.where(status: 'rejected').count
    @new_applications_this_month = applications_scope.where('created_at >= ?', 1.month.ago).count
    
    # Agent Performance Dashboard (real-time mock data)
    @agent_performances = AgentPerformance.active.order(:agent_type, :agent_name) rescue nil
    @recent_agent_tasks = AgentTask.includes(:agent_performance)
                                   .completed
                                   .order(completed_at: :desc)
                                   .limit(20) rescue nil

    # Recent activity - scoped to admin's lender
    if futureproof_admin?
      @recent_user_activity = UserVersion.includes(:user, :admin_user)
                                        .where.not(action: 'viewed')
                                        .order(created_at: :desc)
                                        .limit(10)
      
      @recent_app_activity = ApplicationVersion.includes(:application, :user)
                                             .where.not(action: 'viewed')
                                             .order(created_at: :desc)
                                             .limit(10)
    elsif lender_admin?
      @recent_user_activity = UserVersion.includes(:user, :admin_user)
                                        .joins(:user)
                                        .where(users: { lender: admin_lender })
                                        .where.not(action: 'viewed')
                                        .order(created_at: :desc)
                                        .limit(10)
      
      @recent_app_activity = ApplicationVersion.includes(:application, :user)
                                             .joins(application: :user)
                                             .where(applications: { users: { lender: admin_lender } })
                                             .where.not(action: 'viewed')
                                             .order(created_at: :desc)
                                             .limit(10)
    end
    
    # Status distribution for chart (scoped)
    raw_status_distribution = applications_scope.group(:status).count.transform_keys do |status|
      case status
      when 'created' then 'Created'
      when 'user_details' then 'User Details'
      when 'property_details' then 'Property Details'
      when 'income_and_loan_options' then 'Income & Loan'
      when 'submitted' then 'Submitted'
      when 'processing' then 'Processing'
      when 'accepted' then 'Accepted'
      when 'rejected' then 'Rejected'
      else status.humanize
      end
    end
    
    # Order status distribution in specified order
    status_order = ['Created', 'User Details', 'Property Details', 'Income & Loan', 'Submitted', 'Processing', 'Rejected', 'Accepted']
    @status_distribution = {}
    status_order.each do |status|
      @status_distribution[status] = raw_status_distribution[status] || 0
    end
    
    # Recent applications for quick access (scoped) — actionable pipeline items only
    @recent_applications = applications_scope.includes(:user)
                                           .where(status: %w[submitted processing accepted rejected])
                                           .order(updated_at: :desc)
                                           .limit(5)
    
    # Recent users for quick access (scoped)
    @recent_users = users_scope.order(created_at: :desc).limit(5)
    
    # Growth data for the last 6 months (scoped)
    @application_growth_data = generate_growth_data(applications_scope, 6)
    @conversion_growth_data = generate_conversion_data(users_scope, applications_scope, 6)
    
    # Funds Under Management data (scoped)
    contracts_scope = scoped_contracts
    @monthly_fum_data = generate_monthly_fum_data(contracts_scope, 6)
    @cumulative_fum_data = generate_cumulative_fum_data(contracts_scope, 6)
    
    # WholesaleFunder Pool statistics (only show to Futureproof admins)
    if futureproof_admin?
      @total_pool_capacity = FunderPool.sum(:amount)
      @total_allocated = FunderPool.sum(:allocated)
      @total_available = @total_pool_capacity - @total_allocated
      @pool_utilization = @total_pool_capacity > 0 ? ((@total_allocated.to_f / @total_pool_capacity) * 100).round(1) : 0
      @total_pools = FunderPool.count
      @active_contracts = Contract.where.not(funder_pool_id: nil).count
      
      # WholesaleFunder Pool allocation data for charts
      @pool_allocation_data = generate_pool_allocation_data()
      @pool_utilization_data = generate_pool_utilization_data()
    else
      # Lender admins see basic contract stats only
      @active_contracts = contracts_scope.count
      @pool_allocation_data = []
      @pool_utilization_data = []
    end
  end

  def business
    # Capital Overview
    @total_capital_raised = FunderPool.sum(:amount)
    @capital_deployed = Contract.sum(:allocated_amount)
    @capital_utilisation = @total_capital_raised > 0 ? ((@capital_deployed / @total_capital_raised) * 100).round(1) : 0
    
    # Weighted avg cost of capital
    total_weighted = FunderPool.sum('amount * (benchmark_rate + margin_rate)')
    @wacc = @total_capital_raised > 0 ? (total_weighted / @total_capital_raised).round(2) : 0

    # Portfolio Summary
    @total_contracts = Contract.count
    @active_contracts_count = Contract.where(status: [:ok, :in_holiday]).count
    @total_monthly_outflows = Contract.where(status: [:ok, :in_holiday]).sum(:monthly_payment)
    
    # All contracts for P&L
    @contracts = Contract.includes(:application, :lender, :funder_pool, application: :user).order(:start_date)
    @portfolio_pl = @contracts.sum { |c| contract_net_pl(c) }

    # Wholesale Funders
    @wholesale_funders = WholesaleFunder.includes(funder_pools: :contracts).all

    # Funder Pools
    @funder_pools = FunderPool.includes(:wholesale_funder, :contracts).all

    # Account Balances
    @total_offset = Contract.sum(:offset_balance)
    @total_investment = Contract.sum(:investment_balance)
    @total_account_value = @total_offset + @total_investment
    
    # Weighted avg investment return
    total_inv = Contract.where('investment_balance > 0').sum(:investment_balance)
    weighted_return = Contract.where('investment_balance > 0').sum('investment_balance * investment_return_rate')
    @avg_investment_return = total_inv > 0 ? (weighted_return / total_inv).round(2) : 0

    # Monthly P&L trend data (last 24 months)
    @monthly_pl_data = generate_monthly_pl_data(24)
  end

  private

  def contract_net_pl(c)
    months_active = c.start_date ? [(Date.today - c.start_date).to_i / 30.0, 0].max : 0
    investment_gain = c.investment_balance.to_f * (c.investment_return_rate.to_f / 100.0)
    cost_of_capital = c.allocated_amount.to_f * (c.cost_of_capital_rate.to_f / 100.0) * (months_active / 12.0)
    investment_gain - c.total_payments_made.to_f - cost_of_capital
  end
  helper_method :contract_net_pl

  def generate_monthly_pl_data(months)
    data = {}
    cumulative = 0
    contracts = Contract.where.not(status: :awaiting_funding).where('start_date <= ?', Date.today)
    
    months.times do |i|
      month_date = (months - 1 - i).months.ago.beginning_of_month.to_date
      month_end = month_date.end_of_month
      
      # Contracts active during this month
      active = contracts.where('start_date <= ?', month_end)
      monthly_pl = active.sum { |c|
        # Proportional monthly P&L
        months_active = [(month_end - c.start_date).to_i / 30.0, 0].max
        inv_gain_monthly = c.investment_balance.to_f * (c.investment_return_rate.to_f / 100.0) / [months_active, 1].max
        cost_monthly = c.allocated_amount.to_f * (c.cost_of_capital_rate.to_f / 100.0) / 12.0
        inv_gain_monthly - c.monthly_payment.to_f - cost_monthly
      }
      cumulative += monthly_pl
      data[month_date.strftime('%b %Y')] = { monthly: monthly_pl.round(0), cumulative: cumulative.round(0) }
    end
    data
  end

  def build_attention_items(applications_scope)
    items = []

    # Agent flags/escalations needing review
    flagged_actions = AgentAction.includes(:ai_agent, :actionable)
                                 .where(decision: %w[flag reject], status: 'completed')
                                 .where.not(status: 'overridden')
                                 .order(created_at: :desc)
                                 .limit(10)
    flagged_actions.each do |action|
      next unless action.actionable.present?
      items << {
        type: :agent_flag,
        icon: '⚠️',
        title: "Agent Flagged: #{action.actionable.class.name.titleize} ##{action.actionable.id}",
        subtitle: "#{action.ai_agent&.name || 'Agent'} flagged as #{action.decision}. Confidence: #{(action.confidence.to_f * 100).round(0)}%",
        detail: action.reasoning.to_s.truncate(120),
        url_helper: -> { action.actionable.is_a?(Application) ? admin_application_path(action.actionable) : '#' },
        action_id: action.id,
        created_at: action.created_at
      }
    end

    # Low-confidence decisions (below 70%)
    low_confidence_actions = AgentAction.includes(:ai_agent, :actionable)
                                        .where(status: 'completed')
                                        .where.not(confidence: nil)
                                        .where('confidence < ?', 0.7)
                                        .where.not(id: flagged_actions.map(&:id))
                                        .order(created_at: :desc)
                                        .limit(5)
    low_confidence_actions.each do |action|
      next unless action.actionable.present?
      items << {
        type: :low_confidence,
        icon: '🔍',
        title: "Low Confidence: #{action.action_type.humanize} on #{action.actionable.class.name.titleize} ##{action.actionable.id}",
        subtitle: "#{action.ai_agent&.name || 'Agent'} — #{(action.confidence.to_f * 100).round(0)}% confidence (#{action.decision || 'no decision'})",
        detail: action.reasoning.to_s.truncate(120),
        url_helper: -> { action.actionable.is_a?(Application) ? admin_application_path(action.actionable) : '#' },
        action_id: action.id,
        created_at: action.created_at
      }
    end

    # Documents that agents couldn't verify automatically
    pending_docs = ApplicationDocument.includes(:application)
                                      .where(status: %w[uploaded pending])
                                      .order(created_at: :desc)
    if pending_docs.any?
      grouped = pending_docs.group_by { |d| d.application_id }
      grouped.each do |app_id, docs|
        app = docs.first.application
        next unless app
        doc_names = docs.map { |d| d.document_type.to_s.humanize }.join(', ')
        items << {
          type: :document_review,
          icon: '📄',
          title: "Unverified Documents: #{docs.size} document#{'s' if docs.size != 1} need manual review",
          subtitle: "Application ##{app_id}: #{doc_names.truncate(80)}",
          detail: nil,
          url_helper: -> { admin_application_path(app) },
          action_id: nil,
          created_at: docs.map(&:created_at).max
        }
      end
    end

    items.sort_by { |i| i[:created_at] || Time.at(0) }.reverse.first(10)
  rescue => e
    Rails.logger.error("Dashboard attention items error: #{e.message}")
    []
  end

  def build_agent_performance
    {
      total_today: AgentAction.where('created_at >= ?', Time.current.beginning_of_day).count,
      total_week: AgentAction.where('created_at >= ?', 1.week.ago).count,
      total_all: AgentAction.count,
      avg_confidence: AgentAction.where.not(confidence: nil).average(:confidence)&.round(2) || 0,
      flags_count: AgentAction.where(decision: 'flag', status: 'completed').count,
      escalations_count: AgentAction.where(action_type: 'escalate', status: 'completed').count,
      decision_distribution: AgentAction.where.not(decision: nil).group(:decision).count
    }
  rescue => e
    Rails.logger.error("Dashboard agent performance error: #{e.message}")
    { total_today: 0, total_week: 0, total_all: 0, avg_confidence: 0, flags_count: 0, escalations_count: 0, decision_distribution: {} }
  end

  def build_agent_cards
    AiAgent.active.order(:name).map do |agent|
      actions = agent.agent_actions
      total = actions.count
      approvals = actions.where(decision: 'approve').count
      today_count = actions.where('created_at >= ?', Time.current.beginning_of_day).count
      week_count = actions.where('created_at >= ?', 1.week.ago).count
      avg_conf = actions.where.not(confidence: nil).average(:confidence)&.round(2) || 0
      last_action = actions.maximum(:created_at)
      {
        agent: agent,
        total: total,
        today: today_count,
        week: week_count,
        approval_rate: total > 0 ? (approvals.to_f / total * 100).round(1) : 0,
        avg_confidence: avg_conf,
        last_action_at: last_action,
        active: last_action.present? && last_action > 1.hour.ago
      }
    end
  rescue => e
    Rails.logger.error("Dashboard agent cards error: #{e.message}")
    []
  end

  def generate_growth_data(scope, months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      data[month_name] = scope.where(created_at: month_start..month_end).count
    end
    data.reverse_each.to_h
  end

  def generate_conversion_data(users_scope, applications_scope, months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      
      # Get users created in this month (scoped)
      users_created = users_scope.where(created_at: month_start..month_end).count
      
      # Get applications submitted by users created in this month (scoped)
      submitted_apps = applications_scope.joins(:user)
                                        .where(users: { created_at: month_start..month_end })
                                        .where(status: ['submitted', 'processing', 'accepted', 'rejected'])
                                        .count
      
      # Calculate conversion rate as percentage
      conversion_rate = users_created > 0 ? ((submitted_apps.to_f / users_created) * 100).round(1) : 0
      data[month_name] = conversion_rate
    end
    data.reverse_each.to_h
  end

  def generate_monthly_fum_data(contracts_scope, months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      
      # Get contracts that were created in this month (scoped)
      monthly_fum = contracts_scope.joins(:application)
                                  .where(contracts: { created_at: month_start..month_end })
                                  .where(applications: { home_value: 0.. })
                                  .sum('applications.home_value')
      
      data[month_name] = monthly_fum
    end
    data.reverse_each.to_h
  end

  def generate_cumulative_fum_data(contracts_scope, months)
    data = {}
    months.times do |i|
      month_end = i.months.ago.end_of_month
      month_name = month_end.strftime('%b %Y')
      
      # Get all active contracts up to this month (scoped)
      cumulative_fum = contracts_scope.joins(:application)
                                     .where('contracts.created_at <= ?', month_end)
                                     .where(applications: { home_value: 0.. })
                                     .sum('applications.home_value')
      
      data[month_name] = cumulative_fum
    end
    data.reverse_each.to_h
  end

  def generate_pool_allocation_data
    # Get allocation breakdown by wholesale_funder pool
    FunderPool.includes(:wholesale_funder).map do |pool|
      {
        name: pool.display_name,
        allocated: pool.allocated,
        available: pool.available_amount,
        total: pool.amount,
        utilization: pool.allocation_percentage
      }
    end
  end

  def generate_pool_utilization_data
    # Get utilization data for pie chart
    [
      { label: 'Allocated', value: @total_allocated, color: '#dc2626' },
      { label: 'Available', value: @total_available, color: '#059669' }
    ]
  end
end