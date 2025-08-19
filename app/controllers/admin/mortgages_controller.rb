class Admin::MortgagesController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_mortgage, only: [:show, :edit, :update, :destroy]
  before_action :set_audit_history, only: [:show]

  def index
    @mortgages = Mortgage.includes(:active_lenders).all.order(:name)
    @mortgages = @mortgages.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @mortgages = @mortgages.where(status: params[:status]) if params[:status].present?
    @mortgages = @mortgages.page(params[:page]).per(10)
  end

  def show
    # Eager load lenders and audit history for display
    @mortgage = @mortgage.class.includes(:active_lenders, :mortgage_lenders).find(@mortgage.id)
    collect_all_mortgage_versions
  end

  def new
    @mortgage = Mortgage.new
  end

  def create
    @mortgage = Mortgage.new(mortgage_params)
    @mortgage.current_user = current_user # Track who created it
    
    if @mortgage.save
      redirect_to admin_mortgage_path(@mortgage), notice: 'Mortgage was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Eager load lenders for display
    @mortgage = @mortgage.class.includes(:active_lenders, :mortgage_lenders).find(@mortgage.id)
  end

  def update
    @mortgage.current_user = current_user # Track who updated it
    if @mortgage.update(mortgage_params)
      redirect_to admin_mortgage_path(@mortgage), notice: 'Mortgage was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mortgage.destroy
    redirect_to admin_mortgages_path, notice: 'Mortgage was successfully deleted.'
  end

  private

  def set_mortgage
    @mortgage = Mortgage.find(params[:id])
  end

  def set_audit_history
    @audit_history = @mortgage.mortgage_versions.includes(:user).recent.limit(50)
  end
  
  def collect_all_mortgage_versions
    # Collect all changes: mortgage changes and lender relationship changes
    mortgage_changes = @mortgage.mortgage_versions.includes(:user)
    lender_changes = MortgageLenderVersion.joins(:mortgage_lender)
                                         .where(mortgage_lenders: { mortgage_id: @mortgage.id })
                                         .includes(:user, mortgage_lender: [:lender])
    
    # Combine and sort by creation time
    @all_versions = (mortgage_changes + lender_changes)
                      .sort_by(&:created_at)
                      .reverse
                      .first(50)
  end

  def mortgage_params
    params.require(:mortgage).permit(:name, :mortgage_type, :lvr, :status)
  end
end