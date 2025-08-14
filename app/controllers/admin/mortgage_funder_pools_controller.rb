class Admin::MortgageFunderPoolsController < Admin::BaseController
  before_action :set_mortgage, only: [:new, :create, :edit, :update]
  before_action :set_mortgage_funder_pool, only: [:destroy, :toggle_active]
  
  def new
    @mortgage_funder_pool = @mortgage.mortgage_funder_pools.build
    @available_funder_pools = FunderPool.includes(:funder)
                                       .where.not(id: @mortgage.funder_pools.select(:id))
                                       .order('funders.name, funder_pools.name')
  end
  
  def create
    @mortgage_funder_pool = @mortgage.mortgage_funder_pools.build(mortgage_funder_pool_params)
    
    if @mortgage_funder_pool.save
      redirect_to admin_mortgage_path(@mortgage), notice: 'Funder pool was successfully added to mortgage.'
    else
      @available_funder_pools = FunderPool.includes(:funder)
                                         .where.not(id: @mortgage.funder_pools.select(:id))
                                         .order('funders.name, funder_pools.name')
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    mortgage = @mortgage_funder_pool.mortgage
    @mortgage_funder_pool.destroy
    redirect_to admin_mortgage_path(mortgage), notice: 'Funder pool was successfully removed from mortgage.'
  end
  
  def toggle_active
    @mortgage_funder_pool.toggle_active!
    status = @mortgage_funder_pool.active? ? 'activated' : 'deactivated'
    redirect_to admin_mortgage_path(@mortgage_funder_pool.mortgage), 
                notice: "Funder pool was successfully #{status} for this mortgage."
  end
  
  private
  
  def set_mortgage
    @mortgage = Mortgage.find(params[:mortgage_id])
  end
  
  def set_mortgage_funder_pool
    @mortgage_funder_pool = MortgageFunderPool.find(params[:id])
  end
  
  def mortgage_funder_pool_params
    params.require(:mortgage_funder_pool).permit(:funder_pool_id, :active)
  end
end