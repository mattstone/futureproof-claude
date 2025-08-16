class Admin::LenderWholesaleFundersController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_lender, only: [:new, :create]
  before_action :set_lender_wholesale_funder, only: [:destroy, :toggle_active]
  
  def new
    @lender_wholesale_funder = @lender.lender_wholesale_funders.build
    @available_wholesale_funders = WholesaleFunder.includes(:funder_pools, :lenders)
                                                  .where.not(id: @lender.wholesale_funders.select(:id))
                                                  .order(:name)
    @existing_relationships = @lender.lender_wholesale_funders.includes(:wholesale_funder)
    @existing_pool_relationships = @lender.lender_funder_pools.includes(funder_pool: :wholesale_funder)
  end
  
  def create
    @lender_wholesale_funder = @lender.lender_wholesale_funders.build(lender_wholesale_funder_params)
    
    if @lender_wholesale_funder.save
      redirect_to admin_lender_path(@lender), notice: 'Wholesale funder relationship was successfully created.'
    else
      @available_wholesale_funders = WholesaleFunder.includes(:lenders)
                                                    .where.not(id: @lender.wholesale_funders.select(:id))
                                                    .order(:name)
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    lender = @lender_wholesale_funder.lender
    @lender_wholesale_funder.destroy
    redirect_to admin_lender_path(lender), notice: 'Wholesale funder relationship was successfully removed.'
  end
  
  def toggle_active
    @lender_wholesale_funder.toggle_active!
    status = @lender_wholesale_funder.active? ? 'activated' : 'deactivated'
    redirect_to admin_lender_path(@lender_wholesale_funder.lender), 
                notice: "Wholesale funder relationship was successfully #{status}."
  end

  # AJAX endpoint to add wholesale funder relationship
  def add_wholesale_funder
    @lender = Lender.find(params[:lender_id])
    wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
    
    @lender_wholesale_funder = @lender.lender_wholesale_funders.build(
      wholesale_funder: wholesale_funder,
      active: true
    )
    @lender_wholesale_funder.current_user = current_user if @lender_wholesale_funder.respond_to?(:current_user=)
    
    if @lender_wholesale_funder.save
      @wholesale_funder = wholesale_funder
      @success = true
      @message = "#{wholesale_funder.name} added successfully"
      
      respond_to do |format|
        format.turbo_stream { render "add_wholesale_funder" }
        format.json { 
          render json: { 
            success: true, 
            message: @message,
            wholesale_funder_id: wholesale_funder.id,
            pools: wholesale_funder.funder_pools.map do |pool|
              {
                id: pool.id,
                name: pool.name,
                amount: pool.formatted_amount,
                allocated: pool.formatted_allocated,
                active: false
              }
            end
          }
        }
      end
    else
      @success = false
      @message = @lender_wholesale_funder.errors.full_messages.join(', ')
      
      respond_to do |format|
        format.turbo_stream { render "add_wholesale_funder" }
        format.json { 
          render json: { 
            success: false, 
            message: @message
          }
        }
      end
    end
  end

  # AJAX endpoint to remove wholesale funder relationship
  def remove_wholesale_funder
    @lender = Lender.find(params[:lender_id])
    wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
    
    relationship = @lender.lender_wholesale_funders.find_by(wholesale_funder: wholesale_funder)
    if relationship
      # Remove all associated pool relationships first
      @lender.lender_funder_pools.joins(:funder_pool)
             .where(funder_pools: { wholesale_funder: wholesale_funder })
             .destroy_all
      
      relationship.destroy
      render json: { 
        success: true, 
        message: "#{wholesale_funder.name} removed successfully"
      }
    else
      render json: { success: false, message: "Relationship not found" }
    end
  end

  # Turbo Stream endpoint to toggle funder pool relationship
  def toggle_pool
    @lender = Lender.find(params[:lender_id])
    @funder_pool = FunderPool.find(params[:funder_pool_id])
    
    @relationship = @lender.lender_funder_pools.find_by(funder_pool: @funder_pool)
    
    if @relationship
      @relationship.current_user = current_user if @relationship.respond_to?(:current_user=)
      @relationship.toggle_active!
      @relationship.reload
      @status = @relationship.active? ? 'activated' : 'deactivated'
      @message = "#{@funder_pool.name} #{@status}"
      @success = true
    else
      # Create new relationship
      @relationship = @lender.lender_funder_pools.build(
        funder_pool: @funder_pool,
        active: true
      )
      @relationship.current_user = current_user if @relationship.respond_to?(:current_user=)
      
      if @relationship.save
        @relationship.reload
        @message = "#{@funder_pool.name} activated"
        @success = true
      else
        @message = @relationship.errors.full_messages.join(', ')
        @success = false
      end
    end

    respond_to do |format|
      format.turbo_stream { render "toggle_pool" }
      format.json { 
        render json: { 
          success: @success, 
          message: @message,
          active: @relationship&.active?
        }
      }
      format.html { redirect_to new_admin_lender_wholesale_funder_path(@lender), notice: @message }
    end
  end
  
  private
  
  def set_lender
    @lender = Lender.find(params[:lender_id])
  end
  
  def set_lender_wholesale_funder
    @lender_wholesale_funder = LenderWholesaleFunder.find(params[:id])
  end
  
  def lender_wholesale_funder_params
    params.require(:lender_wholesale_funder).permit(:wholesale_funder_id, :active)
  end
end