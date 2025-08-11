require 'test_helper'

class SecurityEmailTemplateTest < ActionDispatch::IntegrationTest
  setup do
    # Create a minimal user for testing without relying on fixtures
    @user = User.create!(
      email: 'security_test@example.com',
      first_name: 'Security',
      last_name: 'Tester',
      encrypted_password: Devise::Encryptor.digest(User, 'password123'),
      confirmed_at: 1.week.ago
    )
    
    @browser_info = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/91.0.4472.124'
    @ip_address = '192.168.1.100'
    @location = 'San Francisco, CA, US'
  end

  teardown do
    @user.destroy if @user&.persisted?
  end

  test "security notification email processes all template variables correctly" do
    email = UserMailer.security_notification(@user, 'test_sig', @browser_info, @ip_address, @location)
    
    # Check that email can be delivered
    assert_nothing_raised do
      email.deliver_now
    end
    
    # Check subject contains processed variables
    assert_match @user.first_name, email.subject
    
    # Check that body contains processed variables - no template tags should remain for our supported fields
    email_body = email.body.to_s
    
    # Verify no unprocessed template variables remain for supported fields
    supported_user_vars = %w[first_name last_name full_name email]
    supported_security_vars = %w[browser_info ip_address location sign_in_time event_type device_type os_info]
    
    supported_user_vars.each do |var|
      assert_no_match /\{\{user\.#{var}\}\}/i, email_body, "User variable {{user.#{var}}} not processed"
    end
    
    supported_security_vars.each do |var|
      assert_no_match /\{\{security\.#{var}\}\}/i, email_body, "Security variable {{security.#{var}}} not processed"
    end
    
    # Verify actual content is present
    assert_match @user.first_name, email_body, "User first name should be in email body"
    assert_match 'New Browser Sign-in', email_body, "Event type should be in email body"
    assert_match @ip_address, email_body, "IP address should be in email body"
    assert_match @location, email_body, "Location should be in email body"
    assert_match @browser_info, email_body, "Browser info should be in email body"
    assert_match 'macOS', email_body, "OS info should be extracted and included"
    assert_match 'Desktop Computer', email_body, "Device type should be extracted and included"
  end

  test "security notification email extracts device information correctly" do
    # Test with mobile browser
    mobile_browser = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) Mobile/15E148'
    email = UserMailer.security_notification(@user, 'mobile_sig', mobile_browser, @ip_address, @location)
    mobile_body = email.body.to_s
    
    assert_match 'Mobile Device', mobile_body, "Should detect mobile device"
    assert_match 'iOS', mobile_body, "Should detect iOS"
    
    # Test with Windows desktop
    windows_browser = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/91.0.4472.124'
    email = UserMailer.security_notification(@user, 'windows_sig', windows_browser, @ip_address, @location)
    windows_body = email.body.to_s
    
    assert_match 'Desktop Computer', windows_body, "Should detect desktop"
    assert_match 'Windows', windows_body, "Should detect Windows"
  end

  test "security notification email handles missing optional data gracefully" do
    # Test with nil IP and location
    email = UserMailer.security_notification(@user, 'test_sig', @browser_info, nil, nil)
    
    assert_nothing_raised do
      email.deliver_now
    end
    
    email_body = email.body.to_s
    
    # Should still process user and browser info
    assert_match @user.first_name, email_body
    assert_match 'New Browser Sign-in', email_body
    assert_match 'macOS', email_body
    
    # Template variables for missing data should remain unprocessed or be empty
    # (depending on implementation - both are acceptable)
    # The key is that the email should not crash
  end

  test "security notification email timestamp formatting" do
    test_time = Time.new(2023, 12, 25, 14, 30, 0)
    
    # Mock Time.current to return our test time
    Time.stub :current, test_time do
      email = UserMailer.security_notification(@user, 'time_test', @browser_info, @ip_address, @location)
      email_body = email.body.to_s
      
      # Should format timestamp correctly
      assert_match /December 25, 2023 at 02:30 PM/, email_body, "Timestamp should be formatted correctly"
    end
  end

  test "all security template fields are supported by EmailTemplate model" do
    # Verify that EmailTemplate.available_fields includes all the fields we're using
    available_fields = EmailTemplate.available_fields['security_notification']
    
    assert_includes available_fields['user'], 'first_name'
    assert_includes available_fields['user'], 'email'
    
    security_fields = available_fields['security']
    %w[browser_info ip_address location sign_in_time event_type device_type os_info risk_level].each do |field|
      assert_includes security_fields, field, "Security field '#{field}' should be in available_fields"
    end
  end
end