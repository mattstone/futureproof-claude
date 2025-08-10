class Admin::BaseController < ApplicationController
  layout 'admin/application'
  
  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :log_admin_activity

  private

  def ensure_admin
    unless current_user&.admin?
      Rails.logger.warn "[SECURITY] Unauthorized admin access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Path: #{request.fullpath}"
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end
  
  def log_admin_activity
    return unless current_user&.admin?
    
    Rails.logger.info "[ADMIN] #{current_user.email} accessed #{request.fullpath} from IP: #{request.remote_ip}"
  end
end