class Admin::MortgageLendersController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_mortgage
  before_action :set_mortgage_lender, only: [:destroy, :toggle_active]
  
  def available_lenders
    # Get all lenders that are not yet associated with this mortgage
    @available_lenders = Lender.where.not(id: @mortgage.lenders.select(:id))
                               .order(:name)
    
    render json: { 
      lenders: @available_lenders.map do |lender|
        {
          id: lender.id,
          name: lender.name,
          lender_type: lender.lender_type.humanize,
          contact_email: lender.contact_email
        }
      end
    }
  end
  
  def add_lender
    @lender = Lender.find(params[:lender_id])
    
    # Check if relationship already exists
    existing_relationship = @mortgage.mortgage_lenders.find_by(lender: @lender)
    
    if existing_relationship
      # Reactivate if inactive
      if !existing_relationship.active?
        existing_relationship.current_user = current_user
        existing_relationship.update!(active: true)
        flash[:notice] = "#{@lender.name} re-activated for this mortgage."
      else
        flash[:alert] = "#{@lender.name} is already associated with this mortgage."
      end
    else
      # Create new relationship
      relationship = @mortgage.mortgage_lenders.build(
        lender: @lender,
        active: true
      )
      relationship.current_user = current_user
      
      if relationship.save
        flash[:notice] = "#{@lender.name} added to mortgage successfully."
      else
        flash[:alert] = "Failed to add #{@lender.name}: #{relationship.errors.full_messages.join(', ')}"
      end
    end
    
    respond_to do |format|
      format.turbo_stream { render 'add_lender' }
      format.html { redirect_to admin_mortgage_path(@mortgage) }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Lender not found."
    respond_to do |format|
      format.turbo_stream { render 'error' }
      format.html { redirect_to admin_mortgage_path(@mortgage) }
    end
  end
  
  def destroy
    @lender = @mortgage_lender.lender
    @mortgage_lender.current_user = current_user
    
    if @mortgage_lender.destroy
      flash[:notice] = "#{@lender.name} removed from mortgage successfully."
    else
      flash[:alert] = "Failed to remove #{@lender.name}: #{@mortgage_lender.errors.full_messages.join(', ')}"
    end
    
    respond_to do |format|
      format.turbo_stream { render 'destroy' }
      format.html { redirect_to admin_mortgage_path(@mortgage) }
    end
  end
  
  def toggle_active
    @lender = @mortgage_lender.lender
    @mortgage_lender.current_user = current_user
    new_status = !@mortgage_lender.active?
    
    if @mortgage_lender.update(active: new_status)
      status_text = new_status ? "activated" : "deactivated"
      flash[:notice] = "#{@lender.name} #{status_text} successfully."
    else
      flash[:alert] = "Failed to update #{@lender.name}: #{@mortgage_lender.errors.full_messages.join(', ')}"
    end
    
    respond_to do |format|
      format.turbo_stream { render 'toggle_active' }
      format.html { redirect_to admin_mortgage_path(@mortgage) }
    end
  end
  
  private
  
  def set_mortgage
    @mortgage = Mortgage.find(params[:mortgage_id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Mortgage not found."
    redirect_to admin_mortgages_path
  end
  
  def set_mortgage_lender
    @mortgage_lender = @mortgage.mortgage_lenders.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Lender relationship not found."
    respond_to do |format|
      format.turbo_stream { render 'error' }
      format.html { redirect_to admin_mortgage_path(@mortgage) }
    end
  end
end