class Admin::TermsOfUsesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_terms_of_use, only: [:show, :edit, :update, :activate]
  layout 'admin/application'

  def index
    @terms_of_uses = TermsOfUse.order(version: :desc).page(params[:page]).per(10)
  end

  def show
    @audit_history = @terms_of_use.terms_of_use_versions
                                  .includes(:user)
                                  .recent_first
                                  .page(params[:page])
                                  .per(10)
  end

  def new
    @terms_of_use = TermsOfUse.new
    # Copy content from the latest existing terms of use
    latest_terms = TermsOfUse.latest
    if latest_terms
      @terms_of_use.title = latest_terms.title
      @terms_of_use.content = latest_terms.content
    else
      # Fallback to basic template if no existing terms
      @terms_of_use.title = "Terms of Use"
      @terms_of_use.content = <<~MARKUP
        ## 1. Introduction

        Enter your terms content here...

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
    @terms_of_use = TermsOfUse.new(terms_of_use_params)
    @terms_of_use.is_active = false # New versions start as inactive
    @terms_of_use.current_user = current_user # Track who created it
    
    if @terms_of_use.save
      redirect_to admin_terms_of_uses_path, notice: 'Terms of Use created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @terms_of_use.current_user = current_user # Track who updated it
    if @terms_of_use.update(terms_of_use_params)
      redirect_to admin_terms_of_uses_path, notice: 'Terms of Use updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    @terms_of_use.current_user = current_user # Track who activated it
    @terms_of_use.update!(is_active: true)
    redirect_to admin_terms_of_uses_path, notice: 'Terms of Use activated successfully.'
  end

  def preview
    @terms_of_use = TermsOfUse.new(terms_of_use_params)
    @terms_of_use.last_updated = Time.current
    render layout: false
  end

  private

  def set_terms_of_use
    @terms_of_use = TermsOfUse.find(params[:id])
  end

  def terms_of_use_params
    params.require(:terms_of_use).permit(:title, :content, :version)
  end
end