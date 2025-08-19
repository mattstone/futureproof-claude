class Admin::LenderFunderPoolsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_lender, only: [:new, :create, :available_pools, :add_pool, :destroy, :toggle_active]
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
    @lender_funder_pool.current_user = current_user if @lender_funder_pool.respond_to?(:current_user=)
    
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
    @lender = @lender_funder_pool.lender
    @lender_funder_pool.current_user = current_user if @lender_funder_pool.respond_to?(:current_user=)
    @lender_funder_pool.destroy
    
    respond_to do |format|
      format.turbo_stream { render "destroy" }
      format.html { redirect_to admin_lender_path(@lender), notice: 'Funder pool was successfully removed from lender.' }
    end
  end
  
  def toggle_active
    @lender = @lender_funder_pool.lender
    @lender_funder_pool.current_user = current_user if @lender_funder_pool.respond_to?(:current_user=)
    
    begin
      @lender_funder_pool.toggle_active!
      @success = true
      status = @lender_funder_pool.active? ? 'activated' : 'deactivated'
      @message = "#{@lender_funder_pool.funder_pool.name} was successfully #{status} for this lender."
    rescue ActivationBlockedError => e
      @success = false
      @message = e.message
    rescue => e
      @success = false
      @message = "Failed to update funder pool status: #{e.message}"
    end
    
    respond_to do |format|
      format.turbo_stream { render "toggle_active" }
      format.html do
        if @success
          redirect_to admin_lender_path(@lender), notice: @message
        else
          redirect_to admin_lender_path(@lender), alert: @message
        end
      end
    end
  end

  # AJAX endpoint to get available funder pools for selection
  def available_pools
    
    # Get pools from wholesale funders that this lender has active relationships with
    # but exclude pools that are already selected by this lender
    @available_pools = FunderPool.joins(:wholesale_funder)
                                 .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                 .where(lender_wholesale_funders: { lender_id: @lender.id, active: true })
                                 .where.not(id: @lender.funder_pools.select(:id))
                                 .includes(:wholesale_funder)
                                 .order('wholesale_funders.name, funder_pools.name')
    
    render json: {
      funder_pools: @available_pools.map do |pool|
        {
          id: pool.id,
          name: pool.name,
          formatted_amount: pool.formatted_amount,
          formatted_available: pool.formatted_available
        }
      end
    }
  end

  # AJAX endpoint to add funder pool relationship
  def add_pool
    funder_pool = FunderPool.find(params[:funder_pool_id])
    
    @lender_funder_pool = @lender.lender_funder_pools.build(
      funder_pool: funder_pool,
      active: true
    )
    @lender_funder_pool.current_user = current_user if @lender_funder_pool.respond_to?(:current_user=)
    
    if @lender_funder_pool.save
      @funder_pool = funder_pool
      @success = true
      @message = "#{funder_pool.name} added successfully"
      
      respond_to do |format|
        format.turbo_stream { render "add_pool" }
        format.html { redirect_to admin_lender_path(@lender), notice: @message }
      end
    else
      @success = false
      @message = @lender_funder_pool.errors.full_messages.join(', ')
      
      respond_to do |format|
        format.turbo_stream { render "add_pool" }
        format.html { redirect_to admin_lender_path(@lender), alert: @message }
      end
    end
  end
  
  private
  
  def set_lender
    @lender = Lender.find(params[:lender_id])
  end
  
  def set_lender_funder_pool
    @lender_funder_pool = @lender.lender_funder_pools.find(params[:id])
  end
  
  def lender_funder_pool_params
    params.require(:lender_funder_pool).permit(:funder_pool_id, :active)
  end
end