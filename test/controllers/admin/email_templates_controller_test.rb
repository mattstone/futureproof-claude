require 'test_helper'

class Admin::EmailTemplatesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = User.create!(
      first_name: 'Admin',
      last_name: 'User',
      email: 'admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: true,
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    @regular_user = User.create!(
      first_name: 'Regular',
      last_name: 'User',
      email: 'user@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: false,
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345679',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    @email_template = EmailTemplate.create!(
      name: 'Test Email Template',
      template_type: 'verification',
      subject: 'Test Subject {{user.first_name}}',
      content: '<p>Hello {{user.first_name}}, your verification code is {{verification.verification_code}}</p>',
      description: 'Test template for verification emails',
      is_active: true
    )
    
    sign_in @admin_user
  end

  test "should get index" do
    get admin_email_templates_path
    assert_response :success
    assert_select 'h1', 'Email Templates'
    assert_select 'td', 'Test Email Template'
  end

  test "should show email template" do
    get admin_email_template_path(@email_template)
    assert_response :success
    assert_select 'h1', /Email Template.*Test Email Template/
  end

  test "should get new" do
    get new_admin_email_template_path
    assert_response :success
    assert_select 'h1', 'Create New Email Template'
  end

  test "should create email template" do
    assert_difference('EmailTemplate.count') do
      post admin_email_templates_path, params: {
        email_template: {
          name: 'New Test Template',
          template_type: 'application_submitted',
          subject: 'New Template Subject',
          content: '<p>New template content</p>',
          description: 'New template description'
        }
      }
    end

    assert_redirected_to admin_email_templates_path
    assert_equal 'Email template created successfully.', flash[:notice]
    
    template = EmailTemplate.find_by(name: 'New Test Template')
    assert_not_nil template
    assert_equal 'application_submitted', template.template_type
  end

  test "should not create invalid email template" do
    assert_no_difference('EmailTemplate.count') do
      post admin_email_templates_path, params: {
        email_template: {
          name: '',
          template_type: 'invalid_type',
          subject: '',
          content: ''
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select '.field_with_errors'
  end

  test "should get edit" do
    get edit_admin_email_template_path(@email_template)
    assert_response :success
    assert_select 'h1', /Edit.*Email Template/
    assert_select 'input[value="Test Email Template"]'
  end

  test "should update email template" do
    patch admin_email_template_path(@email_template), params: {
      email_template: {
        name: 'Updated Template Name',
        subject: 'Updated Subject',
        content: '<p>Updated content</p>'
      }
    }

    assert_redirected_to admin_email_templates_path
    assert_equal 'Email template updated successfully.', flash[:notice]
    
    @email_template.reload
    assert_equal 'Updated Template Name', @email_template.name
    assert_equal 'Updated Subject', @email_template.subject
  end

  test "should not update with invalid data" do
    patch admin_email_template_path(@email_template), params: {
      email_template: {
        name: '',
        subject: '',
        content: ''
      }
    }

    assert_response :unprocessable_entity
    assert_select '.field_with_errors'
  end

  test "should activate email template" do
    # Create another template of same type
    other_template = EmailTemplate.create!(
      name: 'Other Template',
      template_type: 'verification',
      subject: 'Other',
      content: '<p>Other</p>',
      is_active: true
    )
    
    @email_template.update!(is_active: false)
    
    patch activate_admin_email_template_path(@email_template)
    
    assert_redirected_to admin_email_templates_path
    assert_equal 'Email template activated successfully.', flash[:notice]
    
    @email_template.reload
    other_template.reload
    
    assert @email_template.is_active?
    assert_not other_template.is_active?
  end

  test "should deactivate email template" do
    patch deactivate_admin_email_template_path(@email_template)
    
    assert_redirected_to admin_email_templates_path
    assert_equal 'Email template deactivated.', flash[:notice]
    
    @email_template.reload
    assert_not @email_template.is_active?
  end

  test "should preview verification template" do
    get preview_admin_email_template_path(@email_template)
    assert_response :success
    
    # Should render with mailer layout
    assert_select 'body'
    assert_select 'p', /Hello Admin/
  end

  test "should preview application_submitted template" do
    app_template = EmailTemplate.create!(
      name: 'App Template',
      template_type: 'application_submitted',
      subject: 'Application {{application.id}}',
      content: '<p>Property: {{application.address}}</p>',
      is_active: true
    )
    
    get preview_admin_email_template_path(app_template)
    assert_response :success
  end

  test "should preview security_notification template" do
    security_template = EmailTemplate.create!(
      name: 'Security Template',
      template_type: 'security_notification',
      subject: 'Security Alert',
      content: '<p>IP: {{security.ip_address}}</p>',
      is_active: true
    )
    
    get preview_admin_email_template_path(security_template)
    assert_response :success
  end

  test "should return JSON preview" do
    get preview_admin_email_template_path(@email_template), params: { format: :json }
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, 'subject'
    assert_includes json_response.keys, 'content'
    assert_includes json_response['subject'], 'Test Subject Admin'
    assert_includes json_response['content'], 'Hello Admin'
  end

  test "should handle AJAX preview" do
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      subject: 'AJAX Test {{user.first_name}}',
      content: '<p>AJAX content {{user.first_name}}</p>',
      use_sample_data: 'true'
    }, xhr: true
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['subject'], 'AJAX Test Admin'
    assert_includes json_response['content'], 'AJAX content Admin'
  end

  test "should handle AJAX preview without sample data" do
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      subject: 'Test Subject',
      content: '<p>Static content</p>',
      use_sample_data: 'false'
    }, xhr: true
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal 'Test Subject', json_response['subject']
    assert_equal '<p>Static content</p>', json_response['content']
  end

  test "should return error for AJAX preview with missing content" do
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      subject: 'Test'
    }, xhr: true
    
    assert_response :bad_request
    
    json_response = JSON.parse(response.body)
    assert_includes json_response.keys, 'error'
  end

  test "should require admin authentication" do
    sign_out @admin_user
    sign_in @regular_user
    
    get admin_email_templates_path
    # Should redirect to login or show unauthorized
    assert_response :redirect
  end

  test "should require authentication" do
    sign_out @admin_user
    
    get admin_email_templates_path
    assert_redirected_to new_user_session_path
  end

  test "should handle OpenStruct creation in preview" do
    # Test that the controller properly creates OpenStruct for sample application
    app_template = EmailTemplate.create!(
      name: 'App Preview Test',
      template_type: 'application_submitted',
      subject: 'Test App {{application.id}}',
      content: '<p>Address: {{application.address}}</p><p>Value: {{application.formatted_home_value}}</p>',
      is_active: true
    )
    
    # This should not raise an OpenStruct error
    assert_nothing_raised do
      get preview_admin_email_template_path(app_template)
    end
    
    assert_response :success
    assert_select 'p', /Address: 123 Sample Street/
    assert_select 'p', /Value: \$800,000/
  end

  test "should track template creation in audit log" do
    @email_template.current_user = @admin_user
    
    assert_difference('EmailTemplateVersion.count') do
      post admin_email_templates_path, params: {
        email_template: {
          name: 'Audit Test Template',
          template_type: 'verification',
          subject: 'Audit Test',
          content: '<p>Audit test content</p>',
          description: 'For audit testing'
        }
      }
    end
    
    template = EmailTemplate.find_by(name: 'Audit Test Template')
    version = template.email_template_versions.first
    
    assert_equal @admin_user, version.user
    assert_equal 'created', version.action
    assert_includes version.change_details, 'Audit Test Template'
  end

  test "should track template updates in audit log" do
    @email_template.current_user = @admin_user
    
    assert_difference('EmailTemplateVersion.count') do
      patch admin_email_template_path(@email_template), params: {
        email_template: {
          subject: 'Updated Subject for Audit',
          content: '<p>Updated content for audit</p>'
        }
      }
    end
    
    version = @email_template.email_template_versions.order(:created_at).last
    assert_equal @admin_user, version.user
    assert_equal 'updated', version.action
    assert_includes version.change_details, 'Subject changed'
  end
end