class Console::BaseController < ApplicationController
  layout "console"

  JURISDICTIONS = [ "Summary", "AU", "US", "NZ", "UK" ].freeze

  # Region columns are inconsistent across the schema: some hold ISO-ish codes
  # ("AU"), others legacy full names ("Australia") — and dev data even has a few
  # upper-cased ("AUSTRALIA"). One jurisdiction therefore matches a set of
  # accepted column values, so a region filter works whatever the column stores.
  JURISDICTION_ALIASES = {
    "AU" => [ "AU", "Australia", "AUSTRALIA" ],
    "US" => [ "US", "USA", "United States", "UNITED STATES" ],
    "NZ" => [ "NZ", "New Zealand", "NEW ZEALAND" ],
    "UK" => [ "UK", "GB", "United Kingdom", "UNITED KINGDOM" ]
  }.freeze

  # Reverse index: any accepted value (downcased) -> canonical code. Lets us
  # canonicalise current_jurisdiction whether it arrives as a code (FP-admin
  # picker) or a country name (a lender pinned to lender.country).
  CODE_FOR_JURISDICTION = JURISDICTION_ALIASES.flat_map { |code, values|
    values.map { |v| [ v.downcase, code ] }
  }.to_h.freeze

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

  # The accepted column values for the current jurisdiction, or nil when no
  # filter applies ("Summary", or a lender country we can't map). Bridges the
  # code-vs-name column conventions via JURISDICTION_ALIASES.
  def jurisdiction_match_values
    jurisdiction = current_jurisdiction
    return nil if jurisdiction == "Summary"

    code = CODE_FOR_JURISDICTION[jurisdiction.to_s.downcase] || jurisdiction
    JURISDICTION_ALIASES[code] || [ jurisdiction ]
  end
  helper_method :jurisdiction_match_values

  # "Summary" means no filter; otherwise restrict to the selected country.
  def scope_by_jurisdiction(scope, column)
    values = jurisdiction_match_values
    return scope unless values

    scope.where(column => values)
  end

  # Records that carry no region of their own inherit it from their
  # application (contracts, distributions, …) — this is the join key for
  # region-filtering them. nil when no jurisdiction filter is active.
  def region_scoped_application_ids
    return nil unless jurisdiction_match_values

    scope_by_jurisdiction(scoped_applications, :region).select(:id)
  end

  # Lender admins see their own book; Futureproof admins see everything.
  def scoped_applications
    if policy.futureproof?
      Application.all
    else
      Application.joins(:user).where(users: { lender: policy.lender })
    end
  end

  def scoped_contracts
    if policy.futureproof?
      Contract.all
    else
      Contract.joins(application: :user).where(applications: { users: { lender_id: policy.lender&.id } })
    end
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
