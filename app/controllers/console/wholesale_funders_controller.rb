class Console::WholesaleFundersController < Console::ResourceController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_wholesale_funder, only: [ :show, :edit, :update, :suspend, :reactivate ]

  resource WholesaleFunder
  searches "wholesale_funders.name", "wholesale_funders.country"
  sortable name: "wholesale_funders.name",
           country: "wholesale_funders.country",
           capital: "wholesale_funders.total_allocated_amount",
           created: "wholesale_funders.created_at"
  default_sort :created, :desc
  filters country: ->(scope, value) { scope.where(country: value) },
          currency: ->(scope, value) { scope.where(currency: value) }
  preloads :funder_pools

  csv_column("Name") { |f| f.name }
  csv_column("Country") { |f| f.country }
  csv_column("Currency") { |f| f.currency }
  csv_column("Total capital") { |f| f.total_allocated_amount }
  csv_column("Committed") { |f| f.committed_amount }
  csv_column("Available") { |f| f.available_amount }

  def index
    all_funders = WholesaleFunder.includes(:funder_pools)
    total_allocated = all_funders.sum(:total_allocated_amount)
    total_committed = all_funders.sum { |f| f.committed_amount }
    @global_stats = {
      total_allocated: total_allocated,
      total_committed: total_committed,
      total_available: all_funders.sum { |f| f.available_amount },
      utilization_pct: total_allocated.zero? ? 0 : ((total_committed.to_f / total_allocated) * 100).round(2)
    }
    @countries = WholesaleFunder.distinct.pluck(:country).compact.sort
    super
  end

  def show
    @wholesale_funder.log_view_by(current_user)
    @pools = @wholesale_funder.funder_pools.order(:name)
    @onboarding = Console::PartnerOnboarding.for(@wholesale_funder)
    @versions = @wholesale_funder.wholesale_funder_versions.includes(:user).recent.limit(30)
    @lender_relationships = LenderWholesaleFunder.where(wholesale_funder: @wholesale_funder)
                                                 .includes(lender: { lender_funder_pools: :funder_pool })
                                                 .order("lenders.name")
    @monthly_deployment = @wholesale_funder.average_monthly_deployment
  end

  def new
    @wholesale_funder = WholesaleFunder.new
  end

  def create
    @wholesale_funder = WholesaleFunder.new(wholesale_funder_params)
    @wholesale_funder.current_user = current_user

    if @wholesale_funder.save
      redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Wholesale funder created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @wholesale_funder.current_user = current_user

    if @wholesale_funder.update(wholesale_funder_params)
      redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Wholesale funder updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def suspend
    change_status(@wholesale_funder, :suspended)
  end

  def reactivate
    change_status(@wholesale_funder, :active)
  end

  protected

  def base_scope
    WholesaleFunder.all
  end

  def change_status(partner, new_status)
    if params[:reason].blank?
      redirect_to console_wholesale_funder_path(partner), alert: "A reason is required — it goes in the audit log." and return
    end

    partner.update!(status: new_status)
    AuditLog.log_action(
      user: current_user,
      action: new_status == :suspended ? "partner_suspended" : "partner_reactivated",
      resource: partner,
      reason: params[:reason]
    )
    redirect_to console_wholesale_funder_path(partner), notice: "#{partner.name} #{new_status == :suspended ? 'suspended' : 'reactivated'}."
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.includes(:funder_pools).find(params[:id])
  end

  def wholesale_funder_params
    params.require(:wholesale_funder).permit(:name, :country, :currency, :total_allocated_amount)
  end
end
