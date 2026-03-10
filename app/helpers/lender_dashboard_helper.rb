module LenderDashboardHelper
  # Cached stats calculation (1 query instead of 5)
  def lender_stats(user_id, cache_time = 1.hour)
    Rails.cache.fetch("lender_stats:#{user_id}", expires_in: cache_time) do
      stats = Application.where(lender_id: user_id).group(:status).count
      {
        total: stats.values.sum,
        pending: stats[:processing] || 0,
        approved: stats[:accepted] || 0,
        active: stats[:activated] || 0,
        rejected: stats[:rejected] || 0
      }
    end
  end

  # Top borrowers (SQL aggregation, no N+1)
  def top_active_borrowers(user_id, limit = 5)
    Application.select('applications.*, SUM(distributions.amount) as total_distributed')
               .where(lender_id: user_id, status: :activated)
               .joins('LEFT OUTER JOIN distributions ON applications.id = distributions.application_id')
               .group('applications.id')
               .order('total_distributed DESC')
               .limit(limit)
  end

  # Monthly distributions (efficient aggregation)
  def monthly_distributions(user_id, limit = 12)
    Distribution.joins(application: :lender)
                .where(applications: { lender_id: user_id }, distributions: { status: :completed })
                .select("DATE_TRUNC('month', distributions.processed_at) as month, SUM(distributions.amount) as total")
                .group("DATE_TRUNC('month', distributions.processed_at)")
                .order('month DESC')
                .limit(limit)
                .map { |d| [d.month.strftime('%B %Y'), d.total] }
                .to_h
  end

  # Pipeline percentage calculation
  def pipeline_percentage(count, total)
    return 0 if total.to_f.zero?
    (count.to_f / total * 100).round(1)
  end

  # Pipeline bar configuration (consolidates calculation logic)
  def pipeline_bar_config(stats)
    total = stats[:total].to_i
    return [] if total.zero?

    [
      { 
        label: 'Pending', 
        count: stats[:pending], 
        color: 'warning', 
        percentage: pipeline_percentage(stats[:pending], total) 
      },
      { 
        label: 'Approved', 
        count: stats[:approved] - stats[:active], 
        color: 'info', 
        percentage: pipeline_percentage(stats[:approved] - stats[:active], total) 
      },
      { 
        label: 'Active', 
        count: stats[:active], 
        color: 'success', 
        percentage: pipeline_percentage(stats[:active], total) 
      },
      { 
        label: 'Rejected', 
        count: stats[:rejected], 
        color: 'danger', 
        percentage: pipeline_percentage(stats[:rejected], total) 
      }
    ]
  end

  # Format portfolio value (reusable currency formatter)
  def format_portfolio_value(amount)
    "$#{number_with_precision(amount || 0, precision: 0, delimiter: ',')}"
  end

  # Metric card color class helper
  def metric_color_class(metric_type)
    case metric_type
    when :pending
      'stat-count--warning'
    when :active
      'stat-count--success'
    when :portfolio
      'stat-count--info'
    else
      'stat-count--default'
    end
  end
end
