# Service for gathering admin dashboard metrics and analytics
# ✅ CRITICAL: All metrics filtered by jurisdiction
class AdminDashboardService
  def initialize(admin_user, jurisdiction = nil)
    @admin = admin_user
    # ✅ CRITICAL: Determine effective jurisdiction for filtering
    @jurisdiction = jurisdiction || effective_jurisdiction
  end

  # ✅ CRITICAL: System health metrics - filtered by jurisdiction
  def system_health
    apps_scope = scoped_applications

    {
      jurisdiction: @jurisdiction,
      total_applications: apps_scope.count,
      pending_applications: apps_scope.where(status: :processing).count,
      active_loans: apps_scope.where(status: :activated).count,
      rejected_applications: apps_scope.where(status: :rejected).count,
      total_lenders: scoped_lenders.count,
      active_webhooks: scoped_webhooks.where(active: true).count,
      failed_webhooks: scoped_webhook_deliveries.where(delivery_status: :failed).count
    }
  end

  # ✅ CRITICAL: Portfolio metrics - filtered by jurisdiction
  def portfolio_metrics
    applications = scoped_applications.where(status: :activated)
    distributions = scoped_distributions.where(status: :completed)

    {
      jurisdiction: @jurisdiction,
      total_active_portfolio_value: applications.sum(:loan_value),
      total_distributions_paid: distributions.sum(:amount),
      average_loan_amount: applications.count > 0 ? applications.average(:loan_value).round(2) : 0,
      average_loan_term: applications.count > 0 ? applications.average(:loan_term).round(1) : 0,
      total_applications_value: scoped_applications.sum(:loan_value)
    }
  end

  # ✅ CRITICAL: Top performing lenders - filtered by jurisdiction
  def top_lenders(limit = 5)
    scoped_lenders
      .select("lenders.*, COUNT(applications.id) as app_count, SUM(applications.loan_value) as total_portfolio")
      .joins(:applications)
      .where(applications: { status: :activated })
      .group("lenders.id")
      .order("total_portfolio DESC")
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

  # ✅ CRITICAL: Monthly payment summary - filtered by jurisdiction
  def monthly_payments(months = 12)
    scoped_distributions
      .select("DATE_TRUNC('month', processed_at) as month, COUNT(*) as count, SUM(amount) as total")
      .where(status: :completed)
      .where("processed_at > ?", months.months.ago)
      .group("DATE_TRUNC('month', processed_at)")
      .order("month DESC")
      .limit(months)
      .map do |record|
      {
        month: record.month&.strftime("%B %Y") || "Unknown",
        count: record.count,
        total: record.total || 0
      }
    end
  end

  # ✅ CRITICAL: Failed webhook deliveries - filtered by jurisdiction
  def failed_webhooks(limit = 10)
    scoped_webhook_deliveries
      .where(delivery_status: :failed)
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

  # ✅ CRITICAL: System alerts - filtered by jurisdiction
  def system_alerts
    alerts = []

    # Check for failed applications without lender assignment
    unassigned = scoped_applications.where(status: :accepted, lender_id: nil).count
    alerts << { type: :warning, message: "#{unassigned} accepted applications without lender assignment" } if unassigned > 0

    # Check for failed webhook deliveries
    failed_webhooks = scoped_webhook_deliveries.where(delivery_status: :failed).where("failed_at > ?", 24.hours.ago).count
    alerts << { type: :error, message: "#{failed_webhooks} webhook deliveries failed in last 24h" } if failed_webhooks > 0

    # Check for no distributions processed today
    today_distributions = scoped_distributions.where(status: :completed).where("processed_at > ?", Time.current.beginning_of_day).count
    if today_distributions.zero?
      alerts << { type: :info, message: "No distributions processed today in #{@jurisdiction}" }
    end

    alerts
  end

  private

  # ✅ CRITICAL: Determine effective jurisdiction for admin
  def effective_jurisdiction
    if futureproof_admin?
      "Summary"  # Futureproof admins see all
    elsif lender_admin?
      @admin.lender&.country || "Summary"  # Lender admins see only their country
    else
      "Summary"
    end
  end

  # ✅ CRITICAL: Scope queries by jurisdiction
  def scoped_applications
    apps = Application.all
    return apps if @jurisdiction == "Summary"
    apps.where(region: @jurisdiction)
  end

  def scoped_lenders
    lenders = Lender.all
    return lenders if @jurisdiction == "Summary"
    lenders.where(country: @jurisdiction)
  end

  def scoped_distributions
    dists = Distribution.all
    return dists if @jurisdiction == "Summary"
    dists.joins(:application).where(applications: { region: @jurisdiction })
  end

  def scoped_webhooks
    webhooks = Webhook.all
    return webhooks if @jurisdiction == "Summary"
    webhooks.where(jurisdiction: @jurisdiction)
  end

  def scoped_webhook_deliveries
    deliveries = WebhookDelivery.all
    return deliveries if @jurisdiction == "Summary"
    deliveries.joins(:webhook).where(webhooks: { jurisdiction: @jurisdiction })
  end

  def distribution_status_for_lender(lender)
    total = lender.applications.where(@jurisdiction == "Summary" ? {} : { region: @jurisdiction }).count
    completed = lender.applications.joins(:distributions).where(distributions: { status: :completed }).count
    processed_pct = total > 0 ? (completed.to_f / total * 100).round(1) : 0
    {
      total_apps: total,
      with_distributions: completed,
      percentage: processed_pct
    }
  end

  def futureproof_admin?
    @admin&.admin? && @admin&.lender&.lender_type_futureproof?
  end

  def lender_admin?
    @admin&.admin? && @admin&.lender&.lender_type_lender?
  end
end
