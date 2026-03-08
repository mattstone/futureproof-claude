module Broker
  class ApplicationsController < ApplicationController
    before_action :authenticate_broker!
    before_action :authorize_lender_access!
    before_action :set_application, only: [:show]

    def index
      # Broker sees only their applications for lenders they work with
      @lenders = current_broker.lenders
      @applications = ::Application.by_broker(current_broker)
                                     .where(lender_id: @lenders.ids)
                                     .includes(:user, :lender, :distributions)
                                     .order(created_at: :desc)

      @stats = {
        total: @applications.count,
        pending: @applications.where(application_status: :open).count,
        approved: @applications.where(application_status: :converted).count,
        rejected: @applications.where(application_status: 'backoffice_review').count
      }
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
