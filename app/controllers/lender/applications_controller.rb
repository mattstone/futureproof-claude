module Lender
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_lender_admin!
    before_action :set_application, only: [:show, :approve, :reject]

    # Dashboard - list pending applications for this lender
    def index
      @pending_applications = current_user.lender.applications.where(status: :processing).order(created_at: :desc).page(params[:page])
      @approved_applications = current_user.lender.applications.where(status: :accepted).order(created_at: :desc).limit(10)
      @rejected_applications = current_user.lender.applications.where(status: :rejected).order(created_at: :desc).limit(5)
      
      @stats = {
        pending_count: current_user.lender.applications.where(status: :processing).count,
        approved_count: current_user.lender.applications.where(status: :accepted).count,
        rejected_count: current_user.lender.applications.where(status: :rejected).count,
        total_portfolio_value: current_user.lender.applications.where(status: :accepted).sum(:approved_loan_amount).to_i
      }
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
  end
end
