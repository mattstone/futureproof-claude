class ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update, :income_and_loan, :update_income_and_loan, :summary, :submit, :congratulations]

  def new
    # Check if user has an existing application in "created" status
    existing_application = current_user.applications.status_created.first
    
    if existing_application
      # Use the existing application and update it
      @application = existing_application
      
      # Pre-populate home value if passed from home page calculator
      if params[:home_value].present?
        @application.home_value = params[:home_value].to_i
        # Save only the home value update without triggering validations
        @application.update_column(:home_value, @application.home_value)
      end
      
      # Set defaults for form display but don't save status change yet
      @application.status = :property_details
      @application.ownership_status = :individual
      # Set a reasonable default age for the form
      @application.borrower_age = 60 if @application.borrower_age.to_i < 18
    else
      # Create a new application if none exists
      @application = current_user.applications.build
      @application.status = :property_details
      @application.ownership_status = :individual
      @application.borrower_age = 60  # Set reasonable default
      
      # Pre-populate home value if passed from home page calculator
      if params[:home_value].present?
        @application.home_value = params[:home_value].to_i
      end
    end
  end

  def create
    @application = current_user.applications.build(application_params)
    # Set status to property_details for new applications
    @application.status = :property_details
    
    if @application.save
      # Don't advance status yet, just redirect to income and loan page
      redirect_to income_and_loan_application_path(@application), notice: 'Property details saved successfully!'
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
      redirect_to income_and_loan_application_path(@application), notice: 'Property details updated successfully!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def income_and_loan
    # Show income and loan options form (step 3)
    # Ensure we're in the right status for this step
    @application.update(status: :income_and_loan_options) if @application.status_property_details?
  end

  def update_income_and_loan
    # First update the status to income_and_loan_options if not already
    @application.status = :income_and_loan_options unless @application.status_income_and_loan_options?
    
    # Assign parameters and validate with context
    @application.assign_attributes(income_loan_params)
    
    if @application.valid?(:income_loan_update) && @application.save
      # Advance to next step after saving income and loan details
      @application.advance_to_next_step!
      redirect_to summary_application_path(@application), notice: 'Income and loan details saved successfully!'
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
    
    redirect_to congratulations_application_path(@application), notice: 'Your application has been submitted successfully!'
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