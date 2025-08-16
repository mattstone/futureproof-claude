class Admin::LenderFunderPoolsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_lender, only: [:new, :create]
  before_action :set_lender_funder_pool, only: [:destroy, :toggle_active]
  
  def new
    @lender_funder_pool = @lender.lender_funder_pools.build
    # Only show funder pools from wholesale funders that this lender has relationships with
    @available_funder_pools = FunderPool.joins(:wholesale_funder)
                                        .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                        .where(lender_wholesale_funders: { lender_id: @lender.id, active: true })
                                        .where.not(id: @lender.funder_pools.select(:id))
                                        .includes(:wholesale_funder)
                                        .order('wholesale_funders.name, funder_pools.name')
  end
  
  def create
    @lender_funder_pool = @lender.lender_funder_pools.build(lender_funder_pool_params)
    
    if @lender_funder_pool.save
      redirect_to admin_lender_path(@lender), notice: 'Funder pool was successfully added to lender.'
    else
      @available_funder_pools = FunderPool.joins(:wholesale_funder)
                                          .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                          .where(lender_wholesale_funders: { lender_id: @lender.id, active: true })
                                          .where.not(id: @lender.funder_pools.select(:id))
                                          .includes(:wholesale_funder)
                                          .order('wholesale_funders.name, funder_pools.name')
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    lender = @lender_funder_pool.lender
    @lender_funder_pool.destroy
    redirect_to admin_lender_path(lender), notice: 'Funder pool was successfully removed from lender.'
  end
  
  def toggle_active
    @lender_funder_pool.toggle_active!
    status = @lender_funder_pool.active? ? 'activated' : 'deactivated'
    redirect_to admin_lender_path(@lender_funder_pool.lender), 
                notice: "Funder pool was successfully #{status} for this lender."
  end
  
  private
  
  def set_lender
    @lender = Lender.find(params[:lender_id])
  end
  
  def set_lender_funder_pool
    @lender_funder_pool = LenderFunderPool.find(params[:id])
  end
  
  def lender_funder_pool_params
    params.require(:lender_funder_pool).permit(:funder_pool_id, :active)
  end
end