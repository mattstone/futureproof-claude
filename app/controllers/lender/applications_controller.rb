module Lender
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_lender_admin!
    before_action :set_application, only: [:show, :approve, :reject]
    before_action :set_broker_filter

    # Dashboard - list pending applications for this lender
    def index
      @broker_service = BrokerPerformanceService.new(lender: current_user.lender, broker: @selected_broker)
      
      # Filter applications by broker if specified (with eager loading)
      all_applications = @broker_service.filtered_applications
                                        .includes(:user, :broker, :lender, :distributions)
                                        .order(created_at: :desc)
      
      @pending_applications = all_applications.where(status: :processing).page(params[:page])
      @approved_applications = all_applications.where(status: :accepted).limit(10)
      @rejected_applications = all_applications.where(status: :rejected).limit(5)
      
      @stats = {
        pending_count: all_applications.where(status: :processing).count,
        approved_count: all_applications.where(status: :accepted).count,
        rejected_count: all_applications.where(status: :rejected).count,
        total_portfolio_value: all_applications.where(status: :accepted).sum(:approved_loan_amount).to_i
      }
      
      # Broker metrics for sidebar/cards
      @broker_metrics = @broker_service.all_broker_metrics
      @top_brokers = @broker_service.top_brokers(limit: 3)
      @available_brokers = current_user.lender.brokers.active
    end

    # Review screen - show application details for approval
    def show
      authorize_lender_access!(@application)
    end

    # Approve application
    def approve
      authorize_lender_access!(@application)
      
      @application.approve!(
        loan_amount: approval_params[:loan_amount].to_f,
        interest_rate: approval_params[:interest_rate].to_f,
        term_years: approval_params[:term_years].to_i,
        lender: current_user.lender
      )

      # Send approval email to customer
      ApplicationMailer.approval_notification(@application).deliver_later

      redirect_to lender_applications_path, notice: "Application approved successfully. Contract generated."
    rescue => e
      Rails.logger.error("Approval failed for Application #{@application.id}: #{e.message}")
      redirect_to lender_application_path(@application), alert: "Approval failed: #{e.message}"
    end

    # Reject application
    def reject
      authorize_lender_access!(@application)
      
      @application.reject!(
        reason: rejection_params[:reason]
      )

      # Send rejection email to customer
      ApplicationMailer.rejection_notification(@application).deliver_later

      redirect_to lender_applications_path, notice: "Application rejected."
    rescue => e
      Rails.logger.error("Rejection failed for Application #{@application.id}: #{e.message}")
      redirect_to lender_application_path(@application), alert: "Rejection failed: #{e.message}"
    end

    private

    def set_application
      @application = Application.find(params[:id])
    end

    def authorize_lender_access!(application)
      unless application.lender_id == current_user.lender.id || current_user.admin?
        redirect_to lender_applications_path, alert: "You do not have access to this application."
      end
    end

    def verify_lender_admin!
      unless current_user.lender_admin? || current_user.admin?
        redirect_to dashboard_path, alert: "Only lender admins can access this section."
      end
    end

    def approval_params
      params.require(:application).permit(:loan_amount, :interest_rate, :term_years)
    end

    def rejection_params
      params.require(:application).permit(:reason)
    end

    def set_broker_filter
      @selected_broker = nil
      @selected_broker = Broker.find(params[:broker_id]) if params[:broker_id].present?
    end
  end
end
