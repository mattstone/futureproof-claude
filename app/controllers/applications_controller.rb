class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update]

  def new
    @application = current_user.applications.build
    # Set initial status to property_details since user_details is completed during registration
    @application.status = :property_details
  end

  def create
    @application = current_user.applications.build(application_params)
    # Set status to property_details for new applications
    @application.status = :property_details
    
    if @application.save
      # Advance to next step after saving property details
      @application.advance_to_next_step!
      redirect_to application_path(@application), notice: 'Property details saved successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Step 2 completion page - could redirect to step 3 later
  end

  def edit
    # Allow editing of step 2 information
  end

  def update
    if @application.update(application_params)
      redirect_to application_path(@application), notice: 'Property details updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def application_params
    params.require(:application).permit(
      :address, 
      :home_value, 
      :ownership_status, 
      :property_state, 
      :has_existing_mortgage, 
      :existing_mortgage_amount,
      :status,
      :rejected_reason
    )
  end
end