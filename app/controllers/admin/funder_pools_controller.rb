class Admin::FunderPoolsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_wholesale_funder, except: [:index]
  before_action :set_funder_pool, only: [:show, :edit, :update, :destroy]

  def index
    @funder_pools = FunderPool.includes(:wholesale_funder).recent.page(params[:page]).per(20)
    
    # Search filter
    if params[:search].present?
      search_term = params[:search].to_s.strip
      @funder_pools = @funder_pools.where(
        "funder_pools.name ILIKE ? OR wholesale_funders.name ILIKE ?",
        "%#{search_term}%", "%#{search_term}%"
      ).joins(:wholesale_funder)
    end
    
    # Wholesale Funder filter
    if params[:wholesale_funder_id].present?
      @funder_pools = @funder_pools.where(wholesale_funder_id: params[:wholesale_funder_id])
    end
    
    @wholesale_funders_for_filter = WholesaleFunder.order(:name)
  end

  def show
    # Eager load contracts with their applications and users for performance
    @funder_pool = @wholesale_funder.funder_pools.includes(contracts: { application: :user }).find(params[:id])
    @funder_pool.log_view_by(current_user) if current_user
  end

  def new
    @funder_pool = @wholesale_funder.funder_pools.build
  end

  def create
    @funder_pool = @wholesale_funder.funder_pools.build(funder_pool_params)
    @funder_pool.current_user = current_user

    if @funder_pool.save
      redirect_to admin_wholesale_funder_path(@wholesale_funder), notice: 'Funder pool was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @funder_pool.current_user = current_user
    if @funder_pool.update(funder_pool_params)
      redirect_to admin_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool), notice: 'Funder pool was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @funder_pool.destroy
    redirect_to admin_wholesale_funder_path(@wholesale_funder), notice: 'Funder pool was successfully deleted.'
  end
  

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
  end

  def set_funder_pool
    @funder_pool = @wholesale_funder.funder_pools.find(params[:id])
  end

  def funder_pool_params
    params.require(:funder_pool).permit(:name, :amount, :allocated, :benchmark_rate, :margin_rate)
  end
end