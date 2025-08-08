require 'ostruct'

class Admin::EmailTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_email_template, only: [:show, :edit, :update, :activate, :deactivate, :preview]
  layout 'admin/application'

  def index
    @email_templates = EmailTemplate.order(:template_type, :name).page(params[:page]).per(10)
  end

  def show
    @audit_history = @email_template.email_template_versions
                                    .includes(:user)
                                    .recent_first
                                    .page(params[:page])
                                    .per(10)
    @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
  end

  def new
    @email_template = EmailTemplate.new
    @email_template.template_type = params[:template_type] if params[:template_type].present?
  end

  def create
    @email_template = EmailTemplate.new(email_template_params)
    @email_template.current_user = current_user # Track who created it
    
    if @email_template.save
      redirect_to admin_email_templates_path, notice: 'Email template created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
  end

  def update
    @email_template.current_user = current_user # Track who updated it
    if @email_template.update(email_template_params)
      redirect_to admin_email_templates_path, notice: 'Email template updated successfully.'
    else
      @available_fields = EmailTemplate.available_fields[@email_template.template_type] || {}
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    @email_template.current_user = current_user # Track who activated it
    # Deactivate other templates of the same type
    EmailTemplate.where(template_type: @email_template.template_type).update_all(is_active: false)
    @email_template.update!(is_active: true)
    redirect_to admin_email_templates_path, notice: 'Email template activated successfully.'
  end

  def deactivate
    @email_template.current_user = current_user # Track who deactivated it
    @email_template.update!(is_active: false)
    redirect_to admin_email_templates_path, notice: 'Email template deactivated.'
  end

  def preview
    # Create test data for preview
    user = current_user
    
    # Find a sample application if available
    application = Application.joins(:user, :mortgage).first
    mortgage = application&.mortgage || Mortgage.first
    
    # Create sample data based on template type
    case @email_template.template_type
    when 'verification'
      preview_data = {
        user: user,
        verification_code: '123456',
        expires_at: 15.minutes.from_now
      }
    when 'application_submitted'
      preview_data = {
        user: user,
        application: application || create_sample_application(user, mortgage),
        mortgage: mortgage
      }
    when 'security_notification'
      preview_data = {
        user: user,
        browser_info: 'Chrome 120.0 on macOS',
        ip_address: '192.168.1.1',
        location: 'Sydney, Australia',
        sign_in_time: Time.current
      }
    else
      preview_data = { user: user }
    end
    
    rendered = @email_template.render_content(preview_data)
    
    respond_to do |format|
      format.html { 
        # Set instance variables for mailer layout
        @email_content = rendered[:content].html_safe
        @email_title = rendered[:subject]
        render template: 'admin/email_templates/preview', layout: 'mailer'
      }
      format.json { 
        render json: { 
          subject: rendered[:subject], 
          content: rendered[:content] 
        } 
      }
    end
  end

  def preview_ajax
    # AJAX endpoint for live preview in the editor
    template_type = params[:template_type]
    content = params[:content]
    subject = params[:subject]
    use_sample_data = params[:use_sample_data] == 'true'
    
    return render json: { error: 'Missing parameters' }, status: :bad_request if content.blank?
    
    # Create a temporary template object for rendering
    temp_template = EmailTemplate.new(
      template_type: template_type || 'verification',
      content: content,
      subject: subject || 'Preview Subject'
    )
    
    # Create sample data if requested
    preview_data = {}
    if use_sample_data
      user = current_user
      application = Application.joins(:user, :mortgage).first
      mortgage = application&.mortgage || Mortgage.first
      
      case template_type
      when 'verification'
        preview_data = {
          user: user,
          verification_code: '123456',
          expires_at: 15.minutes.from_now
        }
      when 'application_submitted'
        preview_data = {
          user: user,
          application: application || create_sample_application(user, mortgage),
          mortgage: mortgage
        }
      when 'security_notification'
        preview_data = {
          user: user,
          browser_info: 'Chrome 120.0 on macOS',
          ip_address: '192.168.1.1',
          location: 'Sydney, Australia',
          sign_in_time: Time.current
        }
      end
    end
    
    rendered = temp_template.render_content(preview_data)
    
    render json: {
      subject: rendered[:subject],
      content: rendered[:content]
    }
  end

  def test_email
    # Send a test email to the current user
    @email_template = EmailTemplate.find(params[:id])
    
    # Create sample data
    case @email_template.template_type
    when 'verification'
      UserMailer.with(template: @email_template, user: current_user, verification_code: '123456', expires_at: 15.minutes.from_now).verification_code_template.deliver_now
    when 'application_submitted'
      application = Application.joins(:user, :mortgage).first || create_sample_application(current_user, Mortgage.first)
      UserMailer.with(template: @email_template, application: application).application_submitted_template.deliver_now
    when 'security_notification'
      UserMailer.with(template: @email_template, user: current_user, browser_info: 'Test Browser', ip_address: '127.0.0.1', location: 'Test Location', sign_in_time: Time.current).security_notification_template.deliver_now
    end
    
    redirect_to admin_email_template_path(@email_template), notice: 'Test email sent successfully!'
  end

  private

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  end

  def email_template_params
    params.require(:email_template).permit(:name, :subject, :content, :template_type, :description, :is_active, :markup_content)
  end
  
  def create_sample_application(user, mortgage)
    # Create a sample application for preview purposes
    OpenStruct.new(
      id: 123,
      user: user,
      mortgage: mortgage,
      address: '123 Sample Street, Melbourne VIC 3000',
      home_value: 800000,
      existing_mortgage_amount: 200000,
      loan_term: 15,
      borrower_age: 65,
      growth_rate: 3.5,
      formatted_home_value: '$800,000',
      formatted_existing_mortgage_amount: '$200,000',
      formatted_loan_value: '$360,000',
      formatted_growth_rate: '3.50%',
      formatted_future_property_value: '$1,200,000',
      formatted_home_equity_preserved: '$840,000'
    )
  end
end