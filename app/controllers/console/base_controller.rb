class Console::BaseController < ApplicationController
  layout "console"

  JURISDICTIONS = [ "Summary", "AU", "US", "NZ", "UK" ].freeze

  before_action :authenticate_user!
  before_action :require_console_access
  before_action :log_console_activity
  before_action :initialize_jurisdiction

  helper_method :policy, :current_jurisdiction, :attention_counts

  # Jurisdiction switcher in the topbar. Lender admins are pinned to their
  # lender's country by initialize_jurisdiction, so only Futureproof admins
  # can actually switch.
  def set_jurisdiction
    if policy.futureproof? && JURISDICTIONS.include?(params[:jurisdiction])
      session[:console_jurisdiction] = params[:jurisdiction]
    end
    redirect_back fallback_location: console_root_path
  end

  protected

  def policy
    @policy ||= Console::Policy.new(current_user)
  end

  def require_console_access
    return if policy.access?

    Rails.logger.warn "[SECURITY] Unauthorized console access attempt from IP: #{request.remote_ip}, User: #{current_user&.email || 'anonymous'}, Path: #{request.fullpath}"
    redirect_to root_path, alert: "Access denied. Admin privileges required."
  end

  # Per-section gate; controllers declare e.g.
  #   before_action -> { require_capability(:manage_partners) }
  def require_capability(capability)
    return if policy.can?(capability)

    Rails.logger.warn "[SECURITY] Console capability denied (#{capability}) for #{current_user.email}, Path: #{request.fullpath}"
    redirect_to console_root_path, alert: "Access denied. You don't have permission for that section."
  end

  def current_jurisdiction
    if policy.lender?
      policy.lender&.country || "Summary"
    else
      session[:console_jurisdiction] || "Summary"
    end
  end

  # "Summary" means no filter; otherwise restrict to the selected country.
  def scope_by_jurisdiction(scope, column)
    jurisdiction = current_jurisdiction
    return scope if jurisdiction == "Summary"

    scope.where(column => jurisdiction)
  end

  # Same cache key as the old admin so the parallel-run period pays these
  # queries once, not twice.
  def attention_counts
    @attention_counts ||= Rails.cache.fetch("admin/attention_counts", expires_in: 60.seconds) do
      {
        tickets: SupportTicket.where(status: %w[open in_progress]).count,
        applications: Application.where(status: %i[submitted processing]).count,
        change_requests: PromptChangeRequest.where.not(state_cache: %w[merged closed]).count
      }
    end
  end

  private

  def log_console_activity
    Rails.logger.info "[CONSOLE] #{current_user.email} #{request.method} #{request.fullpath} from IP: #{request.remote_ip}"
  end

  def initialize_jurisdiction
    if policy.lender? && policy.lender
      session[:console_jurisdiction] = policy.lender.country
    else
      session[:console_jurisdiction] ||= "Summary"
    end
  end
end
