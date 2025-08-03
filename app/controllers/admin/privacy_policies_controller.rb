class Admin::PrivacyPoliciesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_privacy_policy, only: [:show, :edit, :update, :activate]
  layout 'admin/application'

  def index
    @privacy_policies = PrivacyPolicy.order(version: :desc).page(params[:page]).per(10)
  end

  def show
    @audit_history = @privacy_policy.privacy_policy_versions
                                    .includes(:user)
                                    .recent_first
                                    .page(params[:page])
                                    .per(10)
  end

  def new
    @privacy_policy = PrivacyPolicy.new
    # Copy content from the latest existing privacy policy
    latest_privacy_policy = PrivacyPolicy.latest
    if latest_privacy_policy
      @privacy_policy.title = latest_privacy_policy.title
      @privacy_policy.content = latest_privacy_policy.content
    else
      # Fallback to basic template if no existing privacy policy
      @privacy_policy.title = "Privacy Policy"
      @privacy_policy.content = <<~MARKUP
        ## 1. Introduction

        Enter your privacy policy content here...

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
        Email: privacy@yourcompany.com
        Address: Your Address
      MARKUP
    end
  end

  def create
    @privacy_policy = PrivacyPolicy.new(privacy_policy_params)
    @privacy_policy.is_active = false # New versions start as inactive
    @privacy_policy.current_user = current_user # Track who created it
    
    if @privacy_policy.save
      redirect_to admin_privacy_policies_path, notice: 'Privacy Policy created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @privacy_policy.current_user = current_user # Track who updated it
    if @privacy_policy.update(privacy_policy_params)
      redirect_to admin_privacy_policies_path, notice: 'Privacy Policy updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    @privacy_policy.current_user = current_user # Track who activated it
    @privacy_policy.update!(is_active: true)
    redirect_to admin_privacy_policies_path, notice: 'Privacy Policy activated successfully.'
  end

  def preview
    @privacy_policy = PrivacyPolicy.new(privacy_policy_params)
    @privacy_policy.last_updated = Time.current
    render layout: false
  end

  private

  def set_privacy_policy
    @privacy_policy = PrivacyPolicy.find(params[:id])
  end

  def privacy_policy_params
    params.require(:privacy_policy).permit(:title, :content, :version)
  end
end
