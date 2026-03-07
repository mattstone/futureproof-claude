class LenderDashboard::LenderDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :load_lender

  def index; end

  def applications; end

  def application_detail
    @application = Application.find(params[:id])
  end

  def payments; end

  def reports; end

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
    redirect_to dashboard_path, alert: 'Access denied.' unless @lender
  end

  def lender_params
    params.require(:lender).permit(:name, :contact_email, :contact_telephone, :address, :postcode, :country)
  end
end
