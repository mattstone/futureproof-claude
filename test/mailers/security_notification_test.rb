require 'test_helper'

class SecurityNotificationTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @browser_signature = 'Chrome_macOS'
    @browser_info = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/91.0.4472.124'
    @ip_address = '192.168.1.100'
    @location = 'San Francisco, CA, US'
  end

  test "security_notification email sends successfully" do
    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
    
    assert_emails 1 do
      email.deliver_now
    end
  end

  test "security_notification email has correct recipient" do
    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
    
    assert_equal [@user.email], email.to
  end

  test "security_notification email processes all template variables" do
    # Create a test template with all security variables
    test_template = EmailTemplate.create!(
      name: 'Test Security Template',
      template_type: 'security_notification',
      subject: 'Security Alert - {{security.event_type}} for {{user.first_name}}',
      description: 'Test template for security notifications',
      content: <<~HTML
        <h1>Security Alert</h1>
        <p>Dear {{user.first_name}} {{user.last_name}},</p>
        <p>Event: {{security.event_type}}</p>
        <p>Time: {{security.sign_in_time}}</p>
        <p>IP: {{security.ip_address}}</p>
        <p>Location: {{security.location}}</p>
        <p>Browser: {{security.browser_info}}</p>
        <p>Device: {{security.device_type}}</p>
        <p>OS: {{security.os_info}}</p>
        <p>Risk: {{security.risk_level}}</p>
      HTML
    )

    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
    
    # Check that subject contains processed variables
    assert_match @user.first_name, email.subject
    assert_match 'New Browser Sign-in', email.subject
    
    # Check that body contains processed variables - no template tags should remain
    email_body = email.body.to_s
    
    # Verify no unprocessed template variables remain
    assert_no_match /\{\{user\.\w+\}\}/, email_body, "User template variables not processed"
    assert_no_match /\{\{security\.\w+\}\}/, email_body, "Security template variables not processed"
    
    # Verify actual content is present
    assert_match @user.first_name, email_body
    assert_match @user.last_name, email_body
    assert_match 'New Browser Sign-in', email_body
    assert_match @ip_address, email_body
    assert_match @location, email_body
    assert_match @browser_info, email_body
    assert_match 'macOS', email_body  # OS extracted from browser info
    assert_match 'Desktop Computer', email_body  # Device type extracted
    assert_match 'Low', email_body  # Risk level
  ensure
    test_template&.destroy
  end

  test "security_notification extracts device type correctly" do
    mailer = UserMailer.new
    
    # Test mobile detection
    mobile_browser = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)'
    assert_equal 'Mobile Device', mailer.send(:extract_device_type, mobile_browser)
    
    # Test tablet detection  
    tablet_browser = 'Mozilla/5.0 (iPad; CPU OS 14_7_1 like Mac OS X)'
    assert_equal 'Tablet', mailer.send(:extract_device_type, tablet_browser)
    
    # Test desktop detection
    desktop_browser = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124'
    assert_equal 'Desktop Computer', mailer.send(:extract_device_type, desktop_browser)
    
    # Test unknown
    assert_equal 'Unknown', mailer.send(:extract_device_type, nil)
    assert_equal 'Unknown', mailer.send(:extract_device_type, '')
  end

  test "security_notification extracts OS info correctly" do
    mailer = UserMailer.new
    
    # Test Windows detection
    windows_browser = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124'
    assert_equal 'Windows', mailer.send(:extract_os_info, windows_browser)
    
    # Test macOS detection
    mac_browser = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/91.0.4472.124'
    assert_equal 'macOS', mailer.send(:extract_os_info, mac_browser)
    
    # Test iOS detection
    ios_browser = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X)'
    assert_equal 'iOS', mailer.send(:extract_os_info, ios_browser)
    
    # Test Android detection
    android_browser = 'Mozilla/5.0 (Linux; Android 11; SM-G991B) Chrome/91.0.4472.124'
    assert_equal 'Android', mailer.send(:extract_os_info, android_browser)
    
    # Test Linux detection
    linux_browser = 'Mozilla/5.0 (X11; Linux x86_64) Chrome/91.0.4472.124'
    assert_equal 'Linux', mailer.send(:extract_os_info, linux_browser)
    
    # Test unknown
    assert_equal 'Unknown', mailer.send(:extract_os_info, nil)
    assert_equal 'Unknown', mailer.send(:extract_os_info, '')
  end

  test "security_notification works with nil optional parameters" do
    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, nil, nil)
    
    assert_nothing_raised do
      email.deliver_now
    end
    
    # Should handle nil IP and location gracefully
    email_body = email.body.to_s
    assert_no_match /\{\{security\.\w+\}\}/, email_body, "Template variables not processed with nil values"
  end

  test "security_notification template processes timestamps correctly" do
    test_time = Time.new(2023, 12, 25, 14, 30, 0)
    
    test_template = EmailTemplate.create!(
      name: 'Time Test Template',
      template_type: 'security_notification', 
      subject: 'Security Alert',
      description: 'Test template for time formatting',
      content: '<p>Sign-in time: {{security.sign_in_time}}</p>'
    )

    # Mock Time.current to return our test time
    Time.stub :current, test_time do
      email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
      email_body = email.body.to_s
      
      # Should format as "December 25, 2023 at 02:30 PM"
      assert_match /December 25, 2023 at 02:30 PM/, email_body
    end
  ensure
    test_template&.destroy
  end

  test "security_notification fallback works when no template exists" do
    # Temporarily disable the template
    original_template = EmailTemplate.find_by(template_type: 'security_notification')
    original_template&.update(is_active: false)
    
    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
    
    assert_equal 'Security Alert: Sign-in from New Browser', email.subject
    assert_emails 1 do
      email.deliver_now
    end
  ensure
    original_template&.update(is_active: true)
  end

  test "all security notification template variables are documented in available_fields" do
    available_security_fields = EmailTemplate.available_fields['security_notification']['security']
    
    # Ensure all fields used in render_content are documented
    expected_fields = %w[browser_info ip_address location sign_in_time event_type device_type os_info risk_level]
    
    expected_fields.each do |field|
      assert_includes available_security_fields, field, 
        "Security field '#{field}' should be documented in available_fields"
    end
  end

  test "template rendering handles missing data gracefully" do
    test_template = EmailTemplate.create!(
      name: 'Missing Data Test',
      template_type: 'security_notification',
      subject: 'Alert for {{user.first_name}}',
      description: 'Test missing data handling',
      content: '<p>Missing: {{security.nonexistent_field}}</p><p>Valid: {{user.first_name}}</p>'
    )

    email = UserMailer.security_notification(@user, @browser_signature, @browser_info, @ip_address, @location)
    email_body = email.body.to_s
    
    # Should process valid fields
    assert_match @user.first_name, email_body
    
    # Should leave unknown template variables as-is (they won't be processed)
    assert_match '{{security.nonexistent_field}}', email_body
  ensure
    test_template&.destroy
  end
end