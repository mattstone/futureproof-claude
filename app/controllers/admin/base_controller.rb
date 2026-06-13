class Admin::BaseController < ApplicationController
  layout "admin/application"

  before_action :authenticate_user!
  before_action :ensure_admin
  before_action :log_admin_activity
  before_action :initialize_admin_jurisdiction

  # Public action for setting jurisdiction (accessible via route)
  def set_jurisdiction
    if valid_jurisdiction?(params[:admin_jurisdiction])
      session[:admin_jurisdiction] = params[:admin_jurisdiction]
    end
    redirect_back fallback_location: admin_root_path
  end

  protected

  # Method available to all admin controllers to restrict access to Futureproof admins only
  def ensure_futureproof_admin
    unless futureproof_admin?
      Rails.logger.warn "[SECURITY] Unauthorized Futureproof admin access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Lender: #{current_user&.lender&.name || 'unknown'}, Path: #{request.fullpath}"
      redirect_to admin_root_path, alert: "Access denied. This section is restricted to Futureproof administrators."
    end
  end

  # Sidebar attention badges — cheap counts, cached briefly so every admin
  # page doesn't pay four queries.
  def admin_attention_counts
    @admin_attention_counts ||= Rails.cache.fetch("admin/attention_counts", expires_in: 60.seconds) do
      {
        tickets: SupportTicket.where(status: %w[open in_progress]).count,
        applications: Application.where(status: %i[submitted processing]).count,
        change_requests: PromptChangeRequest.where.not(state_cache: %w[merged closed]).count
      }
    end
  end
  helper_method :admin_attention_counts
  helper_method :futureproof_admin?, :lender_admin?

  private


  def ensure_admin
    unless current_user&.admin?
      Rails.logger.warn "[SECURITY] Unauthorized admin access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Path: #{request.fullpath}"
      redirect_to root_path, alert: "Access denied. Admin privileges required."
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

  def initialize_admin_jurisdiction
    # ✅ CRITICAL: For lender-type admins, set jurisdiction to their lender's country
    # Futureproof admins get "Summary" by default

    if lender_admin? && admin_lender
      session[:admin_jurisdiction] = admin_lender.country
    else
      session[:admin_jurisdiction] ||= "Summary"
    end
  end

  def valid_jurisdiction?(jurisdiction)
    [ "Summary", "AU", "US", "NZ", "UK" ].include?(jurisdiction)
  end

  # ✅ CRITICAL: Get effective jurisdiction for filtering
  # Returns either the selected jurisdiction or all for "Summary"
  def effective_admin_jurisdiction
    selected = session[:admin_jurisdiction] || "Summary"

    # Lender admins can only see their own jurisdiction
    if lender_admin?
      admin_lender&.country || selected
    else
      selected
    end
  end

  # ✅ CRITICAL: Scope queries by admin's jurisdiction access
  def scope_by_admin_jurisdiction(scope)
    jurisdiction = effective_admin_jurisdiction
    return scope if jurisdiction == "Summary"

    scope.where(jurisdiction_field => jurisdiction)
  end

  private

  def jurisdiction_field
    case controller_name
    when "applications"
      :region
    when "lenders"
      :country
    when "brokers"
      :jurisdiction
    else
      :jurisdiction
    end
  end
end
