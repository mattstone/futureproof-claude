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

  # Pipeline percentages (for UI rendering)
  def pipeline_percentages(stats)
    total = stats[:total].to_f
    return {} if total.zero?

    {
      pending: (stats[:pending] / total * 100).round(1),
      approved: ((stats[:approved] - stats[:active]) / total * 100).round(1),
      active: (stats[:active] / total * 100).round(1),
      rejected: (stats[:rejected] / total * 100).round(1)
    }
  end
end
