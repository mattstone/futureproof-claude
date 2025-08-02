class DashboardController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @applications = current_user.applications.recent
    @current_application = @applications.in_progress.first
    @submitted_applications = @applications.completed
  end

  def start_application
    # Show start application page
  end
end