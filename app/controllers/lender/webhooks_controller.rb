module Lender
  class WebhooksController < BaseController
    before_action :set_webhook, only: [:show, :edit, :update, :destroy, :test, :delivery_log, :retry]

    def index
      @webhooks = current_user.webhook_endpoints.order(created_at: :desc)
    end

    def new
      @webhook = current_user.webhook_endpoints.build
    end

    def create
      @webhook = current_user.webhook_endpoints.build(webhook_params)
      if @webhook.save
        redirect_to lender_dashboard_webhooks_path, notice: "Webhook created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @webhook.update(webhook_params)
        redirect_to lender_dashboard_webhooks_path, notice: "Webhook updated successfully"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @webhook.destroy
      redirect_to lender_dashboard_webhooks_path, notice: "Webhook deleted"
    end

    def test
      test_payload = {
        event: 'test',
        timestamp: Time.current.iso8601,
        message: 'This is a test webhook from FutureProof EPM'
      }
      
      service = WebhookDeliveryService.new(@webhook)
      @response = service.deliver_test(test_payload)
      
      respond_to do |format|
        format.json { render json: @response }
      end
    end

    def delivery_log
      @events = @webhook.webhook_events.order(created_at: :desc).page(params[:page]).per(20)
    end

    def retry
      event = @webhook.webhook_events.find(params[:event_id])
      event.update(status: :pending, attempt_count: 0)
      WebhookDeliveryJob.perform_later(event.id)
      redirect_to lender_dashboard_webhook_delivery_log_path(@webhook), notice: "Webhook retry queued"
    end

    private

    def set_webhook
      @webhook = current_user.webhook_endpoints.find(params[:id])
    end

    def webhook_params
      params.require(:webhook_endpoint).permit(:url, events: [])
    end
  end
end
