class Admin::FunderPoolsController < Admin::BaseController
  before_action :set_funder, except: [:index]
  before_action :set_funder_pool, only: [:show, :edit, :update, :destroy]

  def index
    @funder_pools = FunderPool.includes(:funder).recent.page(params[:page]).per(20)
    
    # Search filter
    if params[:search].present?
      search_term = params[:search].to_s.strip
      @funder_pools = @funder_pools.where(
        "funder_pools.name ILIKE ? OR funders.name ILIKE ?",
        "%#{search_term}%", "%#{search_term}%"
      ).joins(:funder)
    end
    
    # Funder filter
    if params[:funder_id].present?
      @funder_pools = @funder_pools.where(funder_id: params[:funder_id])
    end
    
    @funders_for_filter = Funder.order(:name)
  end

  def show
  end

  def new
    @funder_pool = @funder.funder_pools.build
  end

  def create
    @funder_pool = @funder.funder_pools.build(funder_pool_params)

    if @funder_pool.save
      redirect_to admin_funder_path(@funder), notice: 'Funder pool was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @funder_pool.update(funder_pool_params)
      redirect_to admin_funder_funder_pool_path(@funder, @funder_pool), notice: 'Funder pool was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @funder_pool.destroy
    redirect_to admin_funder_path(@funder), notice: 'Funder pool was successfully deleted.'
  end
  

  private

  def set_funder
    @funder = Funder.find(params[:funder_id])
  end

  def set_funder_pool
    @funder_pool = @funder.funder_pools.find(params[:id])
  end

  def funder_pool_params
    params.require(:funder_pool).permit(:name, :amount, :allocated)
  end
end
