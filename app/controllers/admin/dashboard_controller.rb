module Admin
  class DashboardController < BaseController
    # Admin dashboard with system metrics, lender analytics, payment summary
    def index
      @service = AdminDashboardService.new(current_user)
      
      # System health metrics
      @health = @service.system_health
      
      # Portfolio metrics
      @portfolio = @service.portfolio_metrics
      
      # Top lenders
      @top_lenders = @service.top_lenders(5)
      
      # Monthly payment trend
      @monthly_payments = @service.monthly_payments(12)
      
      # Failed webhooks (alerts)
      @failed_webhooks = @service.failed_webhooks(10)
      
      # System alerts
      @alerts = @service.system_alerts
    end

    # Webhook management (view, retry, disable)
    def webhooks
      @webhooks = Webhook.all.includes(:webhook_deliveries)
      @recent_deliveries = WebhookDelivery.order(created_at: :desc).limit(20)
    end

    # Retry failed webhook delivery
    def retry_webhook
      delivery = WebhookDelivery.find(params[:id])
      
      if delivery.delivery_status == 'failed' && delivery.retry_count < 3
        service = WebhookService.new(delivery.webhook)
        service.deliver_retry(delivery)
        redirect_to admin_dashboard_webhooks_path, notice: "Webhook retry queued"
      else
        redirect_to admin_dashboard_webhooks_path, alert: "Cannot retry this webhook"
      end
    end

    # Toggle webhook active status
    def toggle_webhook
      webhook = Webhook.find(params[:id])
      webhook.update(active: !webhook.active)
      redirect_to admin_dashboard_webhooks_path, notice: "Webhook #{webhook.active ? 'enabled' : 'disabled'}"
    end

    # Applications overview with filtering
    def applications
      @applications = Application.includes(:user, :lender, :distributions)
                                 .order(created_at: :desc)
      
      # Apply filters
      @applications = @applications.where(status: params[:status]) if params[:status].present?
      @applications = @applications.where(lender_id: params[:lender_id]) if params[:lender_id].present?
      
      @applications = @applications.page(params[:page]).per(25)
      
      # Stats for filter sidebar
      @status_counts = Application.group(:status).count
      @lenders = Lender.all
    end

    # Payment distribution history
    def payments
      @distributions = Distribution.includes(:application)
                                   .order(processed_at: :desc)
      
      # Apply filters
      @distributions = @distributions.where(status: params[:status]) if params[:status].present?
      @distributions = @distributions.where('processed_at > ?', params[:date].to_date) if params[:date].present?
      
      @distributions = @distributions.page(params[:page]).per(25)
      
      # Summary stats
      @summary = {
        total_paid: Distribution.where(status: :completed).sum(:amount),
        total_pending: Distribution.where(status: [:pending, :processing]).sum(:amount),
        total_failed: Distribution.where(status: :failed).count,
        monthly_average: Distribution.where(status: :completed).where('processed_at > ?', 12.months.ago).group_by_month(:processed_at).sum(:amount).values.sum / 12
      }
    end
  end
end
