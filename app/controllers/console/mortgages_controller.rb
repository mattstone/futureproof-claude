class Console::MortgagesController < Console::ResourceController
  before_action -> { require_capability(:manage_product) }
  before_action :set_mortgage, only: [ :show, :edit, :update ]

  resource Mortgage
  searches "mortgages.name"
  sortable name: "mortgages.name",
           created: "mortgages.created_at"
  default_sort :name, :asc
  filters status: ->(scope, value) { scope.where(status: value) },
          mortgage_type: ->(scope, value) { scope.where(mortgage_type: value) }
  preloads :active_lenders

  csv_column("Name") { |m| m.name }
  csv_column("Type") { |m| m.mortgage_type }
  csv_column("LVR") { |m| m.lvr }
  csv_column("Status") { |m| m.status }

  def show
    @mortgage = Mortgage.includes(:active_lenders, :mortgage_lenders).find(@mortgage.id)
    @published_contracts = @mortgage.mortgage_contracts.published.order(version: :desc)
    @draft_contracts = @mortgage.mortgage_contracts.drafts.order(version: :desc)
    @versions = collect_all_mortgage_versions
    product_applications = Application.where(mortgage_id: @mortgage.id)
    @usage = {
      applications_total: product_applications.count,
      applications_in_flight: product_applications.where(status: %i[submitted processing]).count,
      applications_accepted: product_applications.where(status: %i[accepted activated]).count,
      contracts: Contract.joins(:application).where(applications: { mortgage_id: @mortgage.id }).count
    }
  end

  def new
    @mortgage = Mortgage.new
  end

  def create
    @mortgage = Mortgage.new(mortgage_params)
    @mortgage.current_user = current_user

    if @mortgage.save
      redirect_to console_mortgage_path(@mortgage), notice: "Mortgage created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @mortgage.current_user = current_user

    if @mortgage.update(mortgage_params)
      redirect_to console_mortgage_path(@mortgage), notice: "Mortgage updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mortgage = Mortgage.find(params[:id])

    dependent_applications = Application.where(mortgage_id: @mortgage.id)
    if dependent_applications.exists?
      redirect_to console_mortgage_path(@mortgage), alert: "#{dependent_applications.count} applications reference this product — it can't be deleted." and return
    end

    @mortgage.current_user = current_user
    @mortgage.destroy
    AuditLog.log_action(user: current_user, action: "mortgage_deleted", resource: @mortgage, reason: params[:reason].presence || "No reason given")
    redirect_to console_mortgages_path, notice: "Mortgage deleted."
  end

  protected

  def base_scope
    Mortgage.all
  end

  private

  def set_mortgage
    @mortgage = Mortgage.find(params[:id])
  end

  def collect_all_mortgage_versions
    mortgage_changes = @mortgage.mortgage_versions.includes(:user)
    lender_changes = MortgageLenderVersion.joins(:mortgage_lender)
                                          .where(mortgage_lenders: { mortgage_id: @mortgage.id })
                                          .includes(:user, mortgage_lender: [ :lender ])
    (mortgage_changes + lender_changes).sort_by(&:created_at).reverse.first(50)
  end

  def mortgage_params
    params.require(:mortgage).permit(:name, :mortgage_type, :lvr, :status)
  end
end
