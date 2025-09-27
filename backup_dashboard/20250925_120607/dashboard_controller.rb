class Admin::DashboardController < Admin::BaseController
  def index
    # Get scoped data based on admin type
    users_scope = scoped_users
    applications_scope = scoped_applications
    
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
    
    # Recent applications for quick access (scoped)
    @recent_applications = applications_scope.includes(:user)
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

  private

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