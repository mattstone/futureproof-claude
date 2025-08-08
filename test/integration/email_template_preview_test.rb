require 'test_helper'

class EmailTemplatePreviewTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = User.create!(
      first_name: 'Admin',
      last_name: 'Test',
      email: 'admin@preview-test.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: true,
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )
  end

  test "should preview application submission email without errors" do
    sign_in @admin_user
    
    # Create the actual template that was causing issues
    template = EmailTemplate.create!(
      name: "Application Submission Confirmation",
      template_type: "application_submitted",
      subject: "Application Received - {{application.id}} | Futureproof Financial",
      content: '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Application Submitted</title>
</head>
<body>
    <h1>Hi {{user.first_name}},</h1>
    <p>Your application #{{application.id}} for {{application.address}} has been received.</p>
    <p>Property Value: {{application.formatted_home_value}}</p>
    <p>Status: {{application.status_display}}</p>
</body>
</html>',
      description: "Email sent to users when they successfully submit a mortgage application",
      is_active: true
    )

    # This should not raise an OpenStruct error
    assert_nothing_raised do
      get preview_admin_email_template_path(template)
    end

    assert_response :success
    
    # Verify content is rendered properly
    assert_select 'h1', /Hi Admin/
    assert_select 'p', /application #123/
    assert_select 'p', /123 Sample Street/
    assert_select 'p', /\$800,000/
  end

  test "should preview security notification email without errors" do
    sign_in @admin_user
    
    template = EmailTemplate.create!(
      name: "Security Alert Notification",
      template_type: "security_notification", 
      subject: "Security Alert - Unusual Activity Detected | Futureproof Financial",
      content: '<!DOCTYPE html>
<html>
<head><title>Security Alert</title></head>
<body>
    <h1>Security Alert for {{user.first_name}}</h1>
    <p>Unusual activity detected:</p>
    <ul>
        <li>IP: {{security.ip_address}}</li>
        <li>Browser: {{security.browser_info}}</li>
        <li>Location: {{security.location}}</li>
        <li>Time: {{security.sign_in_time}}</li>
    </ul>
</body>
</html>',
      description: "Email sent when suspicious account activity is detected",
      is_active: true
    )

    assert_nothing_raised do
      get preview_admin_email_template_path(template)
    end

    assert_response :success
    assert_select 'h1', /Security Alert for Admin/
    assert_select 'li', /IP: 192.168.1.1/
    assert_select 'li', /Browser: Chrome/
    assert_select 'li', /Location: Sydney/
  end

  test "should preview email verification template without errors" do
    sign_in @admin_user
    
    template = EmailTemplate.create!(
      name: "Email Address Verification",
      template_type: "verification",
      subject: "Verify Your Email Address | Futureproof Financial", 
      content: '<!DOCTYPE html>
<html>
<head><title>Email Verification</title></head>
<body>
    <h1>Welcome {{user.first_name}}!</h1>
    <p>Your verification code is: <strong>{{verification.verification_code}}</strong></p>
    <p>This code expires at {{verification.formatted_expires_at}}</p>
    <p>Sent to: {{user.email}}</p>
</body>
</html>',
      description: "Email sent to new users to verify their email address during registration",
      is_active: true
    )

    assert_nothing_raised do
      get preview_admin_email_template_path(template)
    end

    assert_response :success
    assert_select 'h1', /Welcome Admin/
    assert_select 'strong', '123456'
    assert_select 'p', /admin@preview-test.com/
  end

  test "should handle JSON preview requests" do
    sign_in @admin_user
    
    template = EmailTemplate.create!(
      name: "JSON Preview Test",
      template_type: "verification",
      subject: "JSON Test {{user.first_name}}",
      content: '<p>JSON content for {{user.first_name}}</p>',
      is_active: true
    )

    get preview_admin_email_template_path(template, format: :json)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "JSON Test Admin", json_response['subject']
    assert_includes json_response['content'], 'JSON content for Admin'
  end

  test "should handle AJAX preview with all template types" do
    sign_in @admin_user

    # Test verification template
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      subject: 'AJAX Verification {{user.first_name}}',
      content: '<p>Code: {{verification.verification_code}}</p>',
      use_sample_data: 'true'
    }, xhr: true

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json['subject'], 'AJAX Verification Admin'
    assert_includes json['content'], 'Code: 123456'

    # Test application_submitted template
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'application_submitted',
      subject: 'AJAX Application {{application.id}}',
      content: '<p>Address: {{application.address}}</p>',
      use_sample_data: 'true'
    }, xhr: true

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json['content'], 'Address: 123 Sample Street'

    # Test security_notification template
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'security_notification',
      subject: 'AJAX Security Alert',
      content: '<p>Location: {{security.location}}</p>',
      use_sample_data: 'true'
    }, xhr: true

    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json['content'], 'Location: Sydney, Australia'
  end

  test "should render with mailer layout" do
    sign_in @admin_user
    
    template = EmailTemplate.create!(
      name: "Layout Test",
      template_type: "verification",
      subject: "Layout Test",
      content: '<h1>Layout Test Content</h1>',
      is_active: true
    )

    get preview_admin_email_template_path(template)
    assert_response :success

    # Should render with proper HTML structure from mailer layout
    assert_select 'html'
    assert_select 'head'
    assert_select 'body'
    assert_select 'h1', 'Layout Test Content'
  end

  test "should handle missing application data gracefully" do
    sign_in @admin_user
    
    # Remove all applications to test fallback behavior
    Application.destroy_all
    Mortgage.destroy_all

    template = EmailTemplate.create!(
      name: "Missing Data Test",
      template_type: "application_submitted",
      subject: "Test {{application.id}}",
      content: '<p>Address: {{application.address}}</p>',
      is_active: true
    )

    # Should create sample application via OpenStruct when no real data exists
    assert_nothing_raised do
      get preview_admin_email_template_path(template)
    end

    assert_response :success
    # Should still render with sample data
    assert_select 'p', /Address: 123 Sample Street/
  end

  test "should validate required libraries are loaded" do
    # Ensure OpenStruct is available
    assert defined?(OpenStruct), "OpenStruct should be loaded for email template previews"
    
    # Test that we can create OpenStruct objects
    sample_app = OpenStruct.new(id: 123, address: 'Test Address')
    assert_equal 123, sample_app.id
    assert_equal 'Test Address', sample_app.address
  end
end