module BrokerPortal
  class CommissionsController < ApplicationController
    before_action :authenticate_broker!
    before_action :set_period

    def index
      @total_earned = BrokerCommissionCalculator.total_earned_commissions(current_broker, @period_start, @period_end)
      @total_unpaid = BrokerCommissionCalculator.total_unpaid_commissions(current_broker, @period_start, @period_end)
      @total_pending = BrokerCommission.for_broker(current_broker).pending.sum(:commission_amount).to_f

      @commissions = BrokerCommissionCalculator.commissions_by_period(current_broker, @period_start, @period_end)
                                               .includes(application: :user)
                                               .page(params[:page])
                                               .per(20)

      # Commission summary by status
      @commissions_by_status = current_broker.broker_commissions
                                             .for_period(@period_start, @period_end)
                                             .group(:status)
                                             .sum(:commission_amount)

      # Top earning applications
      @top_applications = current_broker.broker_commissions
                                        .joins(:application)
                                        .includes(:application)
                                        .for_period(@period_start, @period_end)
                                        .order(commission_amount: :desc)
                                        .limit(5)

      # Handle export requests
      if params[:format] == "csv"
        export_to_csv
      end
    end

    def export_to_csv
      service = BrokerCommissionInvoiceService.new(
        broker: current_broker,
        period_start: @period_start,
        period_end: @period_end
      )

      filename = "broker_commissions_#{@period_start.strftime('%Y%m%d')}_#{@period_end.strftime('%Y%m%d')}.csv"

      send_data(
        service.to_csv,
        type: "text/csv",
        disposition: "attachment",
        filename: filename
      )
    end

    private

    def set_period
      case params[:period]
      when "year"
        @period_start = 1.year.ago.beginning_of_month
        @period_end = Time.current.end_of_month
        @period_label = "Last 12 Months"
      when "quarter"
        @period_start = 3.months.ago.beginning_of_month
        @period_end = Time.current.end_of_month
        @period_label = "Last Quarter"
      when "custom"
        @period_start = (params[:start_date].presence && Date.parse(params[:start_date])) || 30.days.ago.to_date
        @period_end = (params[:end_date].presence && Date.parse(params[:end_date])) || Time.current.to_date
        @period_label = "Custom"
      else  # month (default)
        @period_start = 1.month.ago.beginning_of_month
        @period_end = Time.current.end_of_month
        @period_label = "Last 30 Days"
      end
    end

    def authenticate_broker!
      redirect_to root_path, alert: "Access denied" unless user_signed_in? && current_user.is_a?(Broker)
    end
  end
end
