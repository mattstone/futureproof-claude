class LenderDashboard::LenderDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :load_lender

  def index
    # EPM Portfolio Overview
    @portfolio_applications = Application.where(lender: @lender)
    @total_equity_investments = @portfolio_applications.where(status: :accepted).sum(:equity_investment_amount) || 0
    @active_investments = @portfolio_applications.where(status: :accepted).count
    @pending_applications = @portfolio_applications.where(status: :processing).count
    @total_distributions_made = Distribution.joins(:application)
                                          .where(applications: { lender: @lender })
                                          .where(status: :completed)
                                          .sum(:amount) || 0
    @property_portfolio_value = @portfolio_applications.where(status: :accepted).sum(:home_value) || 0
  end

  def applications
    # EPM Investment Applications
    @pending_applications = Application.where(lender: @lender, status: :processing)
    @accepted_applications = Application.where(lender: @lender, status: :accepted)
    @rejected_applications = Application.where(lender: @lender, status: :rejected)
  end

  def application_detail
    @application = Application.where(lender: @lender).find(params[:id])
    @distributions = @application.distributions.order(distribution_date: :desc)
  rescue ActiveRecord::RecordNotFound
    redirect_to lender_dashboard_applications_path, alert: 'Equity investment not found or access denied.'
  end

  def payments
    # Actually "distributions" in EPM - money flowing TO borrowers
    @distributions = Distribution.joins(:application)
                                .where(applications: { lender: @lender })
                                .includes(:application)
                                .order(distribution_date: :desc)
    @total_distributed = @distributions.where(status: :completed).sum(:amount) || 0
    @pending_distributions = @distributions.where(status: :pending).sum(:amount) || 0
    @total_margin_earned = @distributions.where(status: :completed).sum(:lender_margin) || 0
  end

  def reports
    # EPM Portfolio Performance Reports
    @portfolio_stats = {
      total_capital_deployed: @lender.applications.where(status: :accepted).sum(:equity_investment_amount) || 0,
      total_property_value: @lender.applications.where(status: :accepted).sum(:home_value) || 0,
      average_equity_percentage: @lender.applications.where(status: :accepted).average(:equity_percentage) || 0,
      distribution_performance: Distribution.joins(:application)
                                          .where(applications: { lender: @lender })
                                          .group(:status)
                                          .count
    }
  end

  def account; end

  def update_account
    if @lender.update(lender_params)
      redirect_to lender_dashboard_account_path, notice: 'Account updated successfully.'
    else
      render :account, alert: 'Failed to update account.'
    end
  end

  private

  def load_lender
    @lender = current_user.lender
    @region = params[:region]
    redirect_to dashboard_path, alert: 'Access denied.' unless @lender
  end

  def lender_params
    params.require(:lender).permit(:name, :contact_email, :contact_telephone, :address, :postcode, :country)
  end
end
