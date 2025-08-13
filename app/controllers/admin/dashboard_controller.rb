class Admin::DashboardController < Admin::BaseController
  def index
    # User statistics
    @total_users = User.count
    @active_users = User.where.not(confirmed_at: nil).count
    @pending_users = User.where(confirmed_at: nil).count
    @admin_users = User.where(admin: true).count
    @new_users_this_month = User.where('created_at >= ?', 1.month.ago).count
    
    # Application statistics
    @total_applications = Application.count
    @submitted_applications = Application.where(status: ['submitted', 'processing', 'accepted', 'rejected']).count
    @draft_applications = Application.where(status: ['created', 'user_details', 'property_details', 'income_and_loan_options']).count
    @accepted_applications = Application.where(status: 'accepted').count
    @rejected_applications = Application.where(status: 'rejected').count
    @new_applications_this_month = Application.where('created_at >= ?', 1.month.ago).count
    
    # Recent activity - combine user and application versions
    @recent_user_activity = UserVersion.includes(:user, :admin_user)
                                      .where.not(action: 'viewed')
                                      .order(created_at: :desc)
                                      .limit(10)
    
    @recent_app_activity = ApplicationVersion.includes(:application, :user)
                                           .where.not(action: 'viewed')
                                           .order(created_at: :desc)
                                           .limit(10)
    
    # Status distribution for chart
    @status_distribution = Application.group(:status).count.transform_keys do |status|
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
    
    # Recent applications for quick access
    @recent_applications = Application.includes(:user)
                                     .order(updated_at: :desc)
                                     .limit(5)
    
    # Recent users for quick access
    @recent_users = User.order(created_at: :desc).limit(5)
    
    # Growth data for the last 6 months
    @application_growth_data = generate_growth_data(Application, 6)
    @conversion_growth_data = generate_conversion_data(6)
    
    # Funds Under Management data
    @monthly_fum_data = generate_monthly_fum_data(6)
    @cumulative_fum_data = generate_cumulative_fum_data(6)
  end

  private

  def generate_growth_data(model, months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      data[month_name] = model.where(created_at: month_start..month_end).count
    end
    data.reverse_each.to_h
  end

  def generate_conversion_data(months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      
      # Get users created in this month
      users_created = User.where(created_at: month_start..month_end).count
      
      # Get applications submitted by users created in this month
      submitted_apps = Application.joins(:user)
                                 .where(users: { created_at: month_start..month_end })
                                 .where(status: ['submitted', 'processing', 'accepted', 'rejected'])
                                 .count
      
      # Calculate conversion rate as percentage
      conversion_rate = users_created > 0 ? ((submitted_apps.to_f / users_created) * 100).round(1) : 0
      data[month_name] = conversion_rate
    end
    data.reverse_each.to_h
  end

  def generate_monthly_fum_data(months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b %Y')
      
      # Get contracts that were created in this month
      monthly_fum = Contract.joins(:application)
                           .where(contracts: { created_at: month_start..month_end })
                           .where(applications: { home_value: 0.. })
                           .sum('applications.home_value')
      
      data[month_name] = monthly_fum
    end
    data.reverse_each.to_h
  end

  def generate_cumulative_fum_data(months)
    data = {}
    months.times do |i|
      month_end = i.months.ago.end_of_month
      month_name = month_end.strftime('%b %Y')
      
      # Get all active contracts up to this month
      cumulative_fum = Contract.joins(:application)
                              .where('contracts.created_at <= ?', month_end)
                              .where(applications: { home_value: 0.. })
                              .sum('applications.home_value')
      
      data[month_name] = cumulative_fum
    end
    data.reverse_each.to_h
  end
end