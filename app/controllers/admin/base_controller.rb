class Admin::BaseController < ApplicationController
  layout 'admin/application'
  
  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :log_admin_activity

  protected

  # Method available to all admin controllers to restrict access to Futureproof admins only
  def ensure_futureproof_admin
    unless futureproof_admin?
      Rails.logger.warn "[SECURITY] Unauthorized Futureproof admin access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Lender: #{current_user&.lender&.name || 'unknown'}, Path: #{request.fullpath}"
      redirect_to admin_dashboard_index_path, alert: 'Access denied. This section is restricted to Futureproof administrators.'
    end
  end

  private

  def ensure_admin
    Rails.logger.info "[SSO_DEBUG] Admin check - current_user: #{current_user&.id}, email: #{current_user&.email}, admin: #{current_user&.admin?}, user_signed_in: #{user_signed_in?}"
    Rails.logger.info "[SSO_DEBUG] Session ID: #{session.id}, Session contents: #{session.to_hash.except('session_id', '_csrf_token')}"

    unless current_user&.admin?
      Rails.logger.warn "[SECURITY] Unauthorized admin access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Path: #{request.fullpath}"
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    else
      Rails.logger.info "[SSO_DEBUG] Admin access granted for user: #{current_user.email}"
    end
  end
  
  def log_admin_activity
    return unless current_user&.admin?
    
    Rails.logger.info "[ADMIN] #{current_user.email} accessed #{request.fullpath} from IP: #{request.remote_ip}"
  end

  # Lender scoping helpers for admin access control
  def futureproof_admin?
    current_user&.admin? && current_user&.lender&.lender_type_futureproof?
  end

  def lender_admin?
    current_user&.admin? && current_user&.lender&.lender_type_lender?
  end

  def admin_lender
    current_user&.lender
  end

  def scoped_users
    if futureproof_admin?
      User.all
    elsif lender_admin?
      User.where(lender: admin_lender)
    else
      User.none
    end
  end

  def scoped_applications
    if futureproof_admin?
      Application.all
    elsif lender_admin?
      Application.joins(:user).where(users: { lender: admin_lender })
    else
      Application.none
    end
  end

  def scoped_contracts
    if futureproof_admin?
      Contract.all
    elsif lender_admin?
      Contract.joins(application: :user).where(applications: { users: { lender: admin_lender } })
    else
      Contract.none
    end
  end
end