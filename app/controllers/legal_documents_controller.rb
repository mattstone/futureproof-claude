class LegalDocumentsController < ApplicationController
  before_action :authenticate_user!

  def key_facts_sheet
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
    @lender = @application.lender
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end
