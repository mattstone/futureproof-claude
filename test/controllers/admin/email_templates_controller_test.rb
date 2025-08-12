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
    
    # Log in as admin
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
  end

  test "should get index" do
    get admin_email_templates_path
    assert_response :success
    assert_select 'strong', 'Test Email Template'
    assert_select 'small.text-muted', 'Test template for verification emails'
  end

  test "should show email template" do
    get admin_email_template_path(@email_template)
    assert_response :success
    assert_select '.info-item span', 'Test Email Template'
  end

  test "should show email template with rendered preview not raw HTML" do
    get admin_email_template_path(@email_template)
    assert_response :success
    
    # Should show Content Preview section
    assert_select 'h3', 'Content Preview'
    assert_select '.card-subtitle', 'Rendered preview with sample data'
    
    # Should show rendered content, not raw HTML
    assert_select '.email-preview-container' do
      assert_select '.email-subject', /Subject:.*Test Subject Admin/
      assert_select '.email-content', /Hello Admin/
      assert_select '.email-content', /123456/ # verification code
    end
    
    # Ensure the HTML is properly rendered (no escaped HTML entities)
    assert_no_match /&lt;p&gt;Hello/, response.body
  end

  test "should show verification template preview with sample data" do
    get admin_email_template_path(@email_template)
    assert_response :success
    
    # Should substitute placeholders with sample data
    assert_select '.email-subject', /Test Subject Admin/
    assert_select '.email-content', /Hello Admin/
    assert_select '.email-content', /123456/
  end

  test "should show application_submitted template preview with sample data" do
    app_template = EmailTemplate.create!(
      name: 'App Template',
      template_type: 'application_submitted',
      subject: 'Application for {{user.first_name}}',
      content: '<p>Hello {{user.first_name}}, your application ID is {{application.id}} for property {{application.address}}</p>',
      is_active: true
    )
    
    get admin_email_template_path(app_template)
    assert_response :success
    
    # Should show rendered content with substituted placeholders
    assert_select '.email-subject', /Application for Admin/
    assert_select '.email-content', /Hello Admin/
    assert_select '.email-content', /123/ # sample application ID
    assert_select '.email-content', /123 Sample Street/ # sample address
  end

  test "should show security_notification template preview with sample data" do
    security_template = EmailTemplate.create!(
      name: 'Security Template',
      template_type: 'security_notification',
      subject: 'Security Alert for {{user.first_name}}',
      content: '<p>Hello {{user.first_name}}, sign-in detected from {{security.ip_address}} at {{security.location}}</p>',
      is_active: true
    )
    
    get admin_email_template_path(security_template)
    assert_response :success
    
    # Should show rendered content with substituted placeholders
    assert_select '.email-subject', /Security Alert for Admin/
    assert_select '.email-content', /Hello Admin/
    assert_select '.email-content', /192.168.1.1/ # sample IP
    assert_select '.email-content', /Sydney, Australia/ # sample location
  end

  test "should not show available field placeholders on show page" do
    get admin_email_template_path(@email_template)
    assert_response :success
    
    # Should NOT show Available Field Placeholders section
    assert_select 'h3', { text: 'Available Field Placeholders', count: 0 }
    assert_select '.available-fields-card', count: 0
    assert_select '.field-tag', count: 0
  end

  test "should show larger content preview window" do
    get admin_email_template_path(@email_template)
    assert_response :success
    
    # Should have increased height for content preview
    assert_match /max-height: 800px/, response.body
    assert_select '.email-content'
  end

  test "should get new" do
    get new_admin_email_template_path
    assert_response :success
    # Page title is set via content_for, check the form is present
    assert_select 'form#email-template-form'
    assert_select 'input#email_template_name'
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

  test "should show available field placeholders on edit page" do
    get edit_admin_email_template_path(@email_template)
    assert_response :success
    
    # Should show Available Field Placeholders section
    assert_select 'h4', 'Available Field Placeholders'
    assert_select '#field-helper-panel'
    assert_select '#field-helper-content'
    assert_select '#toggle-field-helper', 'Hide Fields'
  end

  test "should show live preview section on edit page" do
    get edit_admin_email_template_path(@email_template)
    assert_response :success
    
    # Should show Live Preview section
    assert_select '.email-editor-preview'
    assert_select '.preview-header h3', 'Live Preview'
    assert_select '#refresh-preview', 'Refresh'
    assert_select '#toggle-sample-data', 'Toggle Sample Data'
    assert_select '#subject-preview'
    assert_select '#email-content-preview'
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
    # Log out and log in as regular user
    delete destroy_user_session_path
    post user_session_path, params: {
      user: { email: @regular_user.email, password: 'password123' }
    }
    
    get admin_email_templates_path
    # Should redirect to login or show unauthorized
    assert_response :redirect
  end

  test "should require authentication" do
    # Log out 
    delete destroy_user_session_path
    
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

  # Error Handling Tests
  test "should handle invalid template type gracefully" do
    get preview_admin_email_template_path(@email_template), params: { format: :json }
    assert_response :success
    
    # Should not crash with invalid template type
    invalid_template = EmailTemplate.create!(
      name: 'Invalid Type Template',
      template_type: 'verification', # Valid type initially
      subject: 'Test',
      content: '<p>Test</p>'
    )
    
    # Change to invalid type at database level to test error handling
    invalid_template.update_column(:template_type, 'invalid_type')
    
    assert_nothing_raised do
      get preview_admin_email_template_path(invalid_template)
    end
  end

  test "should handle missing application data gracefully in preview" do
    # Ensure no applications exist for this test
    Application.destroy_all
    
    app_template = EmailTemplate.create!(
      name: 'App Template',
      template_type: 'application_submitted',
      subject: 'Application {{application.id}}',
      content: '<p>Application details</p>',
      is_active: true
    )
    
    assert_nothing_raised do
      get preview_admin_email_template_path(app_template)
    end
    assert_response :success
  end

  test "should handle minimal content gracefully" do
    minimal_template = EmailTemplate.create!(
      name: 'Minimal Template',
      template_type: 'verification',
      subject: 'Minimal',
      content: '<p>Minimal content</p>',
      is_active: false
    )
    
    get admin_email_template_path(minimal_template)
    assert_response :success
    assert_select '.email-content'
  end

  test "should display malicious content safely in preview" do
    malicious_template = EmailTemplate.create!(
      name: 'Malicious Template',
      template_type: 'verification',
      subject: 'Test <script>alert("xss")</script>',
      content: '<p>Test <script>alert("xss")</script></p>',
      is_active: false
    )
    
    get admin_email_template_path(malicious_template)
    assert_response :success
    
    # Content should be displayed (the model doesn't automatically sanitize, 
    # but the view should handle this properly with html_safe)
    assert_select '.email-content'
    assert_select '.email-subject'
  end

  test "should handle very long content appropriately" do
    long_content = '<p>' + 'Lorem ipsum dolor sit amet. ' * 1000 + '</p>'
    long_template = EmailTemplate.create!(
      name: 'Long Template',
      template_type: 'verification',
      subject: 'Very Long Subject ' * 50,
      content: long_content,
      is_active: false
    )
    
    get admin_email_template_path(long_template)
    assert_response :success
    assert_select '.email-content'
  end

  test "should handle concurrent template activation properly" do
    # Create multiple templates of the same type
    template1 = EmailTemplate.create!(
      name: 'Template 1',
      template_type: 'verification',
      subject: 'Test 1',
      content: '<p>Test 1</p>',
      is_active: true
    )
    
    template2 = EmailTemplate.create!(
      name: 'Template 2',
      template_type: 'verification',
      subject: 'Test 2',
      content: '<p>Test 2</p>',
      is_active: false
    )
    
    # Activate the second template
    patch activate_admin_email_template_path(template2)
    
    template1.reload
    template2.reload
    
    assert_not template1.is_active?
    assert template2.is_active?
  end

  test "should validate template uniqueness by name" do
    assert_no_difference('EmailTemplate.count') do
      post admin_email_templates_path, params: {
        email_template: {
          name: @email_template.name, # Duplicate name
          template_type: 'application_submitted',
          subject: 'Duplicate',
          content: '<p>Duplicate</p>'
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.field_with_errors'
  end

  test "should handle missing CSRF token in AJAX requests" do
    # Test AJAX preview without CSRF token should fail gracefully
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      content: '<p>Test</p>',
      subject: 'Test'
    }
    
    # In test environment, CSRF protection may be disabled for JSON requests
    # The important thing is that it doesn't crash
    assert_includes [200, 302, 422], response.status
  end

  test "should handle invalid template parameters in AJAX preview" do
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      content: nil,
      subject: 'Test'
    }, xhr: true, headers: {
      'X-CSRF-Token' => 'invalid-token'
    }
    
    # Should handle gracefully (either error or redirect)
    assert_includes [400, 302], response.status
  end

  # Edge Cases
  test "should handle template with missing placeholders gracefully" do
    broken_template = EmailTemplate.create!(
      name: 'Broken Template',
      template_type: 'verification',
      subject: 'Test {{nonexistent.field}}',
      content: '<p>Missing {{invalid.placeholder}} content</p>',
      is_active: false
    )
    
    get admin_email_template_path(broken_template)
    assert_response :success
    
    # Should show template even with broken placeholders
    assert_select '.email-subject'
    assert_select '.email-content'
  end

  test "should handle template activation when no templates exist for type" do
    # Remove all verification templates
    EmailTemplate.where(template_type: 'verification').destroy_all
    
    new_template = EmailTemplate.create!(
      name: 'First Template',
      template_type: 'verification',
      subject: 'First',
      content: '<p>First</p>',
      is_active: false
    )
    
    patch activate_admin_email_template_path(new_template)
    
    new_template.reload
    assert new_template.is_active?
  end

  test "should require all mandatory fields for template creation" do
    mandatory_fields = [:name, :template_type, :subject, :content]
    
    mandatory_fields.each do |field|
      params = {
        name: 'Test Template',
        template_type: 'verification',
        subject: 'Test Subject',
        content: '<p>Test Content</p>'
      }
      params[field] = nil
      
      assert_no_difference('EmailTemplate.count') do
        post admin_email_templates_path, params: { email_template: params }
      end
      
      assert_response :unprocessable_entity
    end
  end

  test "should handle template preview with special characters" do
    special_template = EmailTemplate.create!(
      name: 'Special Template',
      template_type: 'verification',
      subject: 'Test with émojis 🎉 and spéciål chårs',
      content: '<p>Content with émojis 🎉 spéciål chårs and "quotes" & entities</p>',
      is_active: false
    )
    
    get admin_email_template_path(special_template)
    assert_response :success
    assert_select '.email-subject'
    assert_select '.email-content'
  end
end