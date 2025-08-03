class Dashboard::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update, :income_and_loan, :update_income_and_loan, :summary, :submit, :congratulations]
  layout 'dashboard'

  def new
    # Check if user has an existing application in "created" status
    existing_application = current_user.applications.status_created.first
    
    if existing_application
      # Redirect to edit the existing application
      redirect_to edit_dashboard_application_path(existing_application)
      return
    end
    
    # Create a new application if none exists
    @application = current_user.applications.build
    @application.ownership_status = :individual
    
    # Pre-populate home value if passed from home page calculator
    if params[:home_value].present?
      @application.home_value = params[:home_value].to_i
    end
  end

  def create
    @application = current_user.applications.build(application_params)
    @application.status = :property_details
    
    if @application.save
      redirect_to income_and_loan_dashboard_application_path(@application), notice: 'Property details saved successfully!'
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
    # Update status to property_details when updating property details
    @application.assign_attributes(application_params)
    @application.status = :property_details
    
    if @application.save
      redirect_to income_and_loan_dashboard_application_path(@application), notice: 'Property details updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def income_and_loan
    # Show income and loan options form (step 3)
    # Status should already be property_details from previous step
  end

  def update_income_and_loan
    # Assign parameters and validate with context
    @application.assign_attributes(income_loan_params)
    # Set status to income_and_loan_options when completing this step
    @application.status = :income_and_loan_options
    
    if @application.valid?(:income_loan_update) && @application.save
      # Status is now income_and_loan_options after completing income and loan step
      redirect_to summary_dashboard_application_path(@application), notice: 'Income and loan details saved successfully!'
    else
      render :income_and_loan, status: :unprocessable_entity
    end
  end

  def summary
    # Show application summary (step 4)
  end

  def submit
    # Submit the application and send confirmation email
    @application.update!(status: :submitted)
    
    # Send confirmation email
    UserMailer.application_submitted(@application).deliver_now
    
    redirect_to congratulations_dashboard_application_path(@application), notice: 'Your application has been submitted successfully!'
  end

  def congratulations
    # Show congratulations page after submission
  end

  private

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def application_params
    params.require(:application).permit(
      :home_value, 
      :ownership_status, 
      :property_state, 
      :has_existing_mortgage, 
      :existing_mortgage_amount,
      :status,
      :rejected_reason,
      :borrower_age,
      :borrower_names,
      :company_name,
      :super_fund_name
    )
  end

  def income_loan_params
    params.require(:application).permit(
      :loan_term,
      :income_payout_term,
      :mortgage_id,
      :growth_rate
    )
  end
end