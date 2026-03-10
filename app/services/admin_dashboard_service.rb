# Service for gathering admin dashboard metrics and analytics
class AdminDashboardService
  def initialize(admin_user)
    @admin = admin_user
  end

  # System health metrics
  def system_health
    {
      total_applications: Application.count,
      pending_applications: Application.where(status: :processing).count,
      active_loans: Application.where(status: :activated).count,
      rejected_applications: Application.where(status: :rejected).count,
      total_lenders: Lender.count,
      active_webhooks: Webhook.where(active: true).count,
      failed_webhooks: WebhookDelivery.where(delivery_status: :failed).count
    }
  end

  # Portfolio metrics
  def portfolio_metrics
    applications = Application.where(status: :activated)
    {
      total_active_portfolio_value: applications.sum(:loan_value),
      total_distributions_paid: Distribution.where(status: :completed).sum(:amount),
      average_loan_amount: applications.count > 0 ? applications.average(:loan_value).round(2) : 0,
      average_loan_term: applications.count > 0 ? applications.average(:loan_term).round(1) : 0,
      total_applications_value: Application.sum(:loan_value)
    }
  end

  # Top performing lenders
  def top_lenders(limit = 5)
    Lender.select('lenders.*, COUNT(applications.id) as app_count, SUM(applications.loan_value) as total_portfolio')
           .joins(:applications)
           .where(applications: { status: :activated })
           .group('lenders.id')
           .order('total_portfolio DESC')
           .limit(limit)
           .map do |lender|
      {
        name: lender.name,
        applications: lender.app_count || 0,
        portfolio_value: lender.total_portfolio || 0,
        distribution_status: distribution_status_for_lender(lender)
      }
    end
  end

  # Monthly payment summary
  def monthly_payments(months = 12)
    Distribution.select("DATE_TRUNC('month', processed_at) as month, COUNT(*) as count, SUM(amount) as total")
                .where(status: :completed)
                .where('processed_at > ?', months.months.ago)
                .group("DATE_TRUNC('month', processed_at)")
                .order('month DESC')
                .map do |record|
      {
        month: record.month&.strftime('%B %Y') || 'Unknown',
        count: record.count,
        total: record.total || 0
      }
    end
  end

  # Failed webhook deliveries (for alerting)
  def failed_webhooks(limit = 10)
    WebhookDelivery.where(delivery_status: :failed)
                   .order(failed_at: :desc)
                   .limit(limit)
                   .includes(:webhook)
                   .map do |delivery|
      {
        webhook_id: delivery.webhook_id,
        event: delivery.event,
        url: delivery.webhook.url,
        response_code: delivery.response_code,
        failed_at: delivery.failed_at,
        retries: delivery.retry_count
      }
    end
  end

  # System alerts
  def system_alerts
    alerts = []

    # Check for failed applications without lender assignment
    unassigned = Application.where(status: :accepted, lender_id: nil).count
    alerts << { type: :warning, message: "#{unassigned} accepted applications without lender assignment" } if unassigned > 0

    # Check for failed webhook deliveries
    failed_webhooks = WebhookDelivery.where(delivery_status: :failed).where('failed_at > ?', 24.hours.ago).count
    alerts << { type: :error, message: "#{failed_webhooks} webhook deliveries failed in last 24h" } if failed_webhooks > 0

    # Check for no distributions processed today
    today_distributions = Distribution.where(status: :completed).where('processed_at > ?', Time.current.beginning_of_day).count
    if today_distributions.zero?
      alerts << { type: :info, message: "No distributions processed today" }
    end

    alerts
  end

  private

  def distribution_status_for_lender(lender)
    total = lender.applications.count
    completed = lender.applications.joins(:distributions).where(distributions: { status: :completed }).count
    processed_pct = total > 0 ? (completed.to_f / total * 100).round(1) : 0
    {
      total_apps: total,
      with_distributions: completed,
      percentage: processed_pct
    }
  end
end
