module Broker
  class ApplicationsController < ApplicationController
    before_action :authenticate_broker!
    before_action :authorize_lender_access!
    before_action :set_application, only: [ :show ]

    def index
      # Broker sees only their applications for lenders they work with
      @lenders = current_broker.lenders
      @applications = BrokerDashboardCacheService.fetch_applications(current_broker)
      @stats = BrokerDashboardCacheService.fetch_stats(current_broker)
    end

    def show
      @applicant = @application.user
      @distributions = @application.distributions.order(created_at: :desc)
      authorize_broker_can_view!(@application)
    end

    private

    def set_application
      @application = ::Application.find(params[:id])
    end

    def authorize_broker_can_view!(application)
      lender_ids = current_broker.lenders.ids
      redirect_to broker_root_path, alert: "Access denied" unless application.lender_id.in?(lender_ids)
    end

    def authorize_lender_access!
      redirect_to root_path, alert: "No lenders assigned" if current_broker.lenders.empty?
    end
  end
end
