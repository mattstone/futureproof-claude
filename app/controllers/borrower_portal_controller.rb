class BorrowerPortalController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application

  def dashboard; end

  def annuity_schedule; end

  def loan_details; end

  def property_details; end

  def documents; end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end
