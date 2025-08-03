class Dashboard::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application, only: [:show, :edit, :update, :income_and_loan, :update_income_and_loan, :summary, :submit, :congratulations]
  layout 'dashboard'

  def new
    @application = current_user.applications.build
    # Set initial status to property_details since user_details is completed during registration
    @application.status = :property_details
    # Set default ownership_status to individual to ensure the form displays correctly
    @application.ownership_status = :individual
    
    # Pre-populate home value if passed from home page calculator
    if params[:home_value].present?
      @application.home_value = params[:home_value].to_i
    end
  end

  def create
    @application = current_user.applications.build(application_params)
    # Set status to property_details for new applications
    @application.status = :property_details
    
    if @application.save
      # Don't advance status yet, just redirect to income and loan page
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
    if @application.update(application_params)
      redirect_to income_and_loan_dashboard_application_path(@application), notice: 'Property details updated successfully!'
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