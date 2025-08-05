class Admin::TermsAndConditionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_terms_and_condition, only: [:show, :edit, :update, :activate]
  layout 'admin/application'

  def index
    @terms_and_conditions = TermsAndCondition.order(version: :desc).page(params[:page]).per(10)
  end

  def show
    @audit_history = @terms_and_condition.terms_and_condition_versions
                                          .includes(:user)
                                          .recent_first
                                          .page(params[:page])
                                          .per(10)
  end

  def new
    @terms_and_condition = TermsAndCondition.new
    # Copy content from the latest existing terms and conditions
    latest_terms = TermsAndCondition.latest
    if latest_terms
      @terms_and_condition.title = latest_terms.title
      @terms_and_condition.content = latest_terms.content
    else
      # Fallback to basic template if no existing terms
      @terms_and_condition.title = "Terms and Conditions"
      @terms_and_condition.content = <<~MARKUP
        ## 1. Introduction

        Enter your terms and conditions content here...

        ## 2. Your Section

        Add your content using simple markup:
        - Use ## for main headings
        - Use ### for sub-headings  
        - Use - for bullet points
        - Use **text** for bold text

        ### Sub-section Example

        This is how you create sub-sections.

        - First bullet point
        - Second bullet point
        - Third bullet point

        ## Contact Information

        **Contact Info:**
        Company: Your Company Name
        Email: contact@yourcompany.com
        Address: Your Address
      MARKUP
    end
  end

  def create
    @terms_and_condition = TermsAndCondition.new(terms_and_condition_params)
    @terms_and_condition.is_active = false # New versions start as inactive
    @terms_and_condition.current_user = current_user # Track who created it
    
    if @terms_and_condition.save
      redirect_to admin_terms_and_conditions_path, notice: 'Terms and Conditions created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @terms_and_condition.current_user = current_user # Track who updated it
    if @terms_and_condition.update(terms_and_condition_params)
      redirect_to admin_terms_and_conditions_path, notice: 'Terms and Conditions updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    @terms_and_condition.current_user = current_user # Track who activated it
    @terms_and_condition.update!(is_active: true)
    redirect_to admin_terms_and_conditions_path, notice: 'Terms and Conditions activated successfully.'
  end

  def preview
    @terms_and_condition = TermsAndCondition.new(terms_and_condition_params)
    @terms_and_condition.last_updated = Time.current
    render layout: false
  end

  private

  def set_terms_and_condition
    @terms_and_condition = TermsAndCondition.find(params[:id])
  end

  def terms_and_condition_params
    params.require(:terms_and_condition).permit(:title, :content, :version)
  end
end