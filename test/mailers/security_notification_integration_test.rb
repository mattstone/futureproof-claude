require 'test_helper'

class SecurityNotificationIntegrationTest < ActionMailer::TestCase
  def setup
    @user = User.create!(
      first_name: 'John',
      last_name: 'Smith',
      email: 'john.smith@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )

    # Ensure there's a security notification template
    @template = EmailTemplate.find_or_create_by(template_type: 'security_notification') do |template|
      template.name = 'Security Notification'
      template.subject = 'Security Alert: Sign-in from {{security.location}}'
      template.content = <<~HTML
        <h1>Hello {{user.first_name}}</h1>
        <p>Sign-in detected from:</p>
        <ul>
          <li>Location: {{security.location}}</li>
          <li>IP: {{security.ip_address}}</li>
          <li>Browser: {{security.browser_info}}</li>
          <li>Time: {{security.sign_in_time}}</li>
        </ul>
      HTML
      template.is_active = true
    end
  end

  test "security notification with valid location" do
    # Test with real location data
    email = UserMailer.security_notification(
      @user, 
      'browser_123', 
      'Chrome 120.0 on macOS', 
      '203.0.113.1', 
      'Sydney, NSW, Australia'
    )

    assert_emails 1 do
      email.deliver_now
    end

    # Check email properties
    assert_equal [@user.email], email.to
    assert_equal 'Security Alert: Sign-in from Sydney, NSW, Australia', email.subject
    
    # Check email content
    email_body = email.body.to_s
    assert_includes email_body, 'Hello John'
    assert_includes email_body, 'Location: Sydney, NSW, Australia'
    assert_includes email_body, 'IP: 203.0.113.1'
    assert_includes email_body, 'Browser: Chrome 120.0 on macOS'
    assert_includes email_body, 'Time:'
  end

  test "security notification with nil location uses fallback" do
    # Test with nil location (common for local/private IPs)
    email = UserMailer.security_notification(
      @user, 
      'browser_456', 
      'Firefox 119.0 on Windows', 
      '127.0.0.1', 
      nil  # location is nil
    )

    assert_emails 1 do
      email.deliver_now
    end

    # Check that fallback is used in subject
    assert_equal 'Security Alert: Sign-in from Unknown Location', email.subject
    
    # Check that fallback is used in content
    body_content = email.body.to_s
    assert_includes body_content, 'Location: Unknown Location'
    assert_includes body_content, 'IP: 127.0.0.1'
    assert_includes body_content, 'Browser: Firefox 119.0 on Windows'
    
    # Ensure no unsubstituted placeholders remain
    assert_not_includes body_content, '{{security.location}}'
    assert_not_includes body_content, '{{security.ip_address}}'
    assert_not_includes body_content, '{{security.browser_info}}'
    assert_not_includes body_content, '{{user.first_name}}'
  end

  test "security notification with all nil security data" do
    # Test edge case where all security data is nil
    email = UserMailer.security_notification(
      @user, 
      nil,    # browser_signature 
      nil,    # browser_info
      nil,    # ip_address
      nil     # location
    )

    assert_emails 1 do
      email.deliver_now
    end

    # Check that all fallbacks are used
    assert_equal 'Security Alert: Sign-in from Unknown Location', email.subject
    
    body_content = email.body.to_s
    assert_includes body_content, 'Hello John'
    assert_includes body_content, 'Location: Unknown Location'
    assert_includes body_content, 'IP: Unknown IP'
    assert_includes body_content, 'Browser: Unknown Browser'
    
    # Ensure no unsubstituted placeholders remain
    assert_not_includes body_content, '{{security.'
    assert_not_includes body_content, '{{user.'
  end

  test "security notification with empty string values" do
    # Test edge case where security data is empty strings
    email = UserMailer.security_notification(
      @user, 
      '',     # browser_signature 
      '',     # browser_info
      '',     # ip_address
      ''      # location
    )

    assert_emails 1 do
      email.deliver_now
    end

    # Empty strings should be treated as nil and use fallbacks
    body_content = email.body.to_s
    assert_includes body_content, 'Location: Unknown Location'
    assert_includes body_content, 'IP: Unknown IP'
    assert_includes body_content, 'Browser: Unknown Browser'
  end

  test "security notification includes properly formatted timestamp" do
    # Test that timestamp is formatted correctly
    email = UserMailer.security_notification(
      @user, 
      'browser_789', 
      'Safari on iOS', 
      '198.51.100.1', 
      'Toronto, ON, Canada'
    )

    email.deliver_now
    
    body_content = email.body.to_s
    
    # Should contain a properly formatted time
    # Pattern: "Month DD, YYYY at HH:MM AM/PM"
    assert_match /Time: \w+ \d{1,2}, \d{4} at \d{1,2}:\d{2} [AP]M/, body_content
  end

  test "security notification handles special characters in location" do
    # Test with location containing special characters
    location_with_special_chars = 'São Paulo, São Paulo, Brazil'
    
    email = UserMailer.security_notification(
      @user, 
      'browser_special', 
      'Chrome on Android', 
      '200.23.45.67', 
      location_with_special_chars
    )

    email.deliver_now
    
    # Should handle UTF-8 characters properly
    assert_includes email.subject, location_with_special_chars
    assert_includes email.body.to_s, location_with_special_chars
  end

  test "security notification without email template falls back gracefully" do
    # Temporarily disable the template
    @template.update!(is_active: false)
    EmailTemplate.where(template_type: 'security_notification').destroy_all
    
    email = UserMailer.security_notification(
      @user, 
      'browser_fallback', 
      'Edge on Windows', 
      '192.0.2.1', 
      'London, England, UK'
    )

    assert_emails 1 do
      email.deliver_now
    end

    # Should use fallback subject when no template is available
    assert_equal 'Security Alert: Sign-in from New Browser', email.subject
    assert_equal [@user.email], email.to
  end

  test "security job with local IP address uses fallback location" do
    # Test with local IP (which returns nil from geolocation)
    assert_emails 1 do
      SecurityNotificationJob.perform_now(
        @user.id, 
        'test_signature', 
        'Chrome 120.0 on Linux', 
        '127.0.0.1'  # Local IP that will return nil location
      )
    end
    
    # Verify the email was sent with proper fallbacks
    email = ActionMailer::Base.deliveries.last
    assert_equal [@user.email], email.to
    assert_equal 'Security Alert: Sign-in from Unknown Location', email.subject
    assert_includes email.body.to_s, 'Location: Unknown Location'
  end
end