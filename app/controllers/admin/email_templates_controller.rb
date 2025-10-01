require 'ostruct'

class Admin::EmailTemplatesController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_email_template, only: [:show, :edit, :update, :activate, :deactivate, :preview, :send_test]

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
    
    # Generate preview data for the show page
    @preview_data = generate_preview_data_for_show
    @rendered_preview = @email_template.render_content(@preview_data)
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
    
    # Create sample data based on template type
    case @email_template.template_type
    when 'verification'
      preview_data = {
        user: user,
        verification_code: '123456',
        expires_at: 15.minutes.from_now
      }
    when 'application_submitted'
      # Find a sample application if available
      application = Application.joins(:user, :mortgage).first rescue nil
      mortgage = application&.mortgage || Mortgage.first rescue nil
      
      # Always create sample application to ensure preview works
      sample_application = create_sample_application(user, mortgage)
      
      preview_data = {
        user: user,
        application: application || sample_application,
        mortgage: mortgage || create_sample_mortgage
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
    
    # Render content without header/footer since mailer layout will add them
    rendered = @email_template.render_content(preview_data, include_header_footer: false)

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
    content_body = params[:content_body]
    email_category = params[:email_category]
    subject = params[:subject]
    use_sample_data = params[:use_sample_data] == 'true'
    
    return render json: { error: 'Missing parameters' }, status: :bad_request if content_body.blank? && content.blank?
    
    # Create a temporary template object for rendering
    temp_template = EmailTemplate.new(
      template_type: template_type || 'verification',
      content: content,
      content_body: content_body || content,
      email_category: email_category || 'operational',
      subject: subject || 'Preview Subject'
    )
    
    # Create sample data if requested
    preview_data = {}
    if use_sample_data
      user = current_user
      
      case template_type
      when 'verification'
        preview_data = {
          user: user,
          verification_code: '123456',
          expires_at: 15.minutes.from_now
        }
      when 'application_submitted'
        # Try to get real data first, fall back to sample data
        application = Application.joins(:user, :mortgage).first
        mortgage = application&.mortgage || Mortgage.first
        
        # Always create sample application to ensure preview works
        sample_application = create_sample_application(user, mortgage)
        
        preview_data = {
          user: user,
          application: application || sample_application,
          mortgage: mortgage || create_sample_mortgage
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

  def send_test
    # Send a test email to the current user with sample data
    begin
      # Generate sample data based on template type
      test_data = generate_test_data
      
      # Render the email content
      rendered = @email_template.render_content(test_data)
      
      # Send the email using ActionMailer
      AdminMailer.test_email(
        to: current_user.email,
        subject: rendered[:subject],
        content: rendered[:content]
      ).deliver_now
      
      flash[:notice] = "Test email sent successfully to #{current_user.email}!"
    rescue => e
      Rails.logger.error "Failed to send test email: #{e.message}"
      flash[:alert] = "Failed to send test email: #{e.message}"
    end
    
    redirect_back(fallback_location: edit_admin_email_template_path(@email_template))
  end

  private

  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  end

  def email_template_params
    params.require(:email_template).permit(:name, :subject, :content, :content_body, :email_category, :template_type, :description, :is_active, :markup_content)
  end
  
  def create_sample_application(user, mortgage)
    # Create a sample application for preview purposes
    OpenStruct.new(
      id: 123,
      user: user,
      mortgage: mortgage || create_sample_mortgage,
      address: '123 Sample Street, Melbourne VIC 3000',
      home_value: 800000,
      existing_mortgage_amount: 200000,
      loan_term: 15,
      borrower_age: 65,
      growth_rate: 3.5,
      status: 'submitted',
      created_at: 2.days.ago,
      updated_at: 1.day.ago,
      submitted_at: 1.day.ago,
      formatted_home_value: '$800,000',
      formatted_existing_mortgage_amount: '$200,000',
      formatted_loan_value: '$360,000',
      formatted_growth_rate: '3.50%',
      formatted_future_property_value: '$1,200,000',
      formatted_home_equity_preserved: '$840,000',
      status_display: 'Submitted',
      formatted_created_at: 2.days.ago.strftime('%B %d, %Y at %I:%M %p'),
      formatted_updated_at: 1.day.ago.strftime('%B %d, %Y at %I:%M %p'),
      formatted_submitted_at: 1.day.ago.strftime('%B %d, %Y at %I:%M %p'),
      loan_value: 360000,
      future_property_value: 1200000,
      home_equity_preserved: 840000
    )
  end
  
  def create_sample_mortgage
    # Create a sample mortgage for preview purposes
    OpenStruct.new(
      id: 1,
      name: 'Premium Equity Preservation Mortgage®',
      lvr: '60',
      interest_rate: '7.45',
      mortgage_type_display: 'Equity Preservation'
    )
  end
  
  def generate_preview_data_for_show
    user = current_user
    
    case @email_template.template_type
    when 'verification'
      {
        user: user,
        verification_code: '123456',
        expires_at: 15.minutes.from_now
      }
    when 'application_submitted'
      # Try to get real data first, fall back to sample data
      application = Application.joins(:user, :mortgage).first rescue nil
      mortgage = application&.mortgage || Mortgage.first rescue nil
      
      # Always create sample application to ensure preview works
      sample_application = create_sample_application(user, mortgage)
      
      {
        user: user,
        application: application || sample_application,
        mortgage: mortgage || create_sample_mortgage
      }
    when 'security_notification'
      {
        user: user,
        browser_info: 'Chrome 120.0 on macOS',
        ip_address: '192.168.1.1',
        location: 'Sydney, Australia',
        sign_in_time: Time.current
      }
    else
      { user: user }
    end
  end
  
  def generate_test_data
    user = current_user
    
    case @email_template.template_type
    when 'verification'
      {
        user: user,
        verification: {
          verification_code: rand(100000..999999).to_s,
          expires_at: 30.minutes.from_now,
          formatted_expires_at: 30.minutes.from_now.strftime('%I:%M %p')
        }
      }
    when 'application_submitted'
      # Generate random but realistic test data
      sample_home_value = [750000, 850000, 950000, 1200000, 1500000].sample
      sample_loan_value = (sample_home_value * 0.6).to_i
      
      {
        user: user,
        application: {
          id: rand(1000..9999),
          reference_number: sprintf('%06d', rand(1000..999999)),
          address: ['123 Collins Street, Melbourne VIC 3000', '456 George Street, Sydney NSW 2000', '789 King Street, Perth WA 6000'].sample,
          home_value: sample_home_value,
          formatted_home_value: "$#{number_with_commas(sample_home_value)}",
          existing_mortgage_amount: (sample_home_value * 0.2).to_i,
          formatted_existing_mortgage_amount: "$#{number_with_commas((sample_home_value * 0.2).to_i)}",
          loan_value: sample_loan_value,
          formatted_loan_value: "$#{number_with_commas(sample_loan_value)}",
          borrower_age: rand(60..75),
          loan_term: [10, 15, 20, 25].sample,
          growth_rate: [3.0, 3.5, 4.0, 4.5].sample,
          formatted_growth_rate: "#{[3.0, 3.5, 4.0, 4.5].sample}%",
          future_property_value: (sample_home_value * 1.5).to_i,
          formatted_future_property_value: "$#{number_with_commas((sample_home_value * 1.5).to_i)}",
          home_equity_preserved: (sample_home_value * 0.7).to_i,
          formatted_home_equity_preserved: "$#{number_with_commas((sample_home_value * 0.7).to_i)}",
          status: 'submitted',
          status_display: 'Submitted for Review',
          created_at: rand(1..7).days.ago,
          updated_at: rand(1..24).hours.ago,
          submitted_at: rand(1..24).hours.ago,
          formatted_created_at: rand(1..7).days.ago.strftime('%B %d, %Y at %I:%M %p'),
          formatted_updated_at: rand(1..24).hours.ago.strftime('%B %d, %Y at %I:%M %p'),
          formatted_submitted_at: rand(1..24).hours.ago.strftime('%B %d, %Y at %I:%M %p')
        },
        mortgage: {
          name: ['Premium Equity Mortgage', 'Lifetime Equity Release', 'Secure Retirement Mortgage'].sample,
          lvr: ['55', '60', '65'].sample,
          interest_rate: ['6.95', '7.25', '7.45', '7.65'].sample,
          mortgage_type_display: 'Reverse Mortgage'
        }
      }
    when 'security_notification'
      browsers = ['Chrome 120.0 on Windows 10', 'Safari 17.0 on macOS', 'Firefox 119.0 on Ubuntu', 'Edge 119.0 on Windows 11']
      locations = ['Sydney, Australia', 'Melbourne, Australia', 'Brisbane, Australia', 'Perth, Australia']
      
      {
        user: user,
        security: {
          browser_info: browsers.sample,
          ip_address: "#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}.#{rand(1..255)}",
          location: locations.sample,
          sign_in_time: rand(1..60).minutes.ago.strftime('%B %d, %Y at %I:%M %p')
        }
      }
    else
      { user: user }
    end
  end
  
  def number_with_commas(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end