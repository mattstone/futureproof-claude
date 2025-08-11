require 'test_helper'

class EmailTemplateSecurityTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @template = EmailTemplate.create!(
      name: 'Test Security Template',
      template_type: 'security_notification',
      subject: 'Security Alert - {{security.event_type}} for {{user.first_name}}',
      description: 'Test template for security notifications',
      content: <<~HTML
        <div class="security-alert">
          <h1>Security Alert</h1>
          <p>Dear {{user.first_name}} {{user.last_name}},</p>
          <p>We detected unusual activity on your account.</p>
          
          <h2>Event Details</h2>
          <ul>
            <li>Event Type: {{security.event_type}}</li>
            <li>Time: {{security.sign_in_time}}</li>
            <li>IP Address: {{security.ip_address}}</li>
            <li>Location: {{security.location}}</li>
            <li>Browser: {{security.browser_info}}</li>
            <li>Device Type: {{security.device_type}}</li>
            <li>Operating System: {{security.os_info}}</li>
            <li>Risk Level: {{security.risk_level}}</li>
          </ul>
          
          <p>If this was you, no action is needed.</p>
          <p>Contact support: security@futureprooffinancial.co</p>
        </div>
      HTML
    )
  end

  teardown do
    @template.destroy
  end

  test "renders security template with all variables" do
    data = {
      user: @user,
      browser_info: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/91.0.4472.124',
      ip_address: '192.168.1.100',
      location: 'San Francisco, CA, US',
      sign_in_time: Time.new(2023, 12, 25, 14, 30, 0),
      event_type: 'New Browser Sign-in',
      device_type: 'Desktop Computer',
      os_info: 'macOS',
      risk_level: 'Low'
    }

    result = @template.render_content(data)
    
    # Check subject processing
    assert_equal "Security Alert - New Browser Sign-in for #{@user.first_name}", result[:subject]
    
    # Check content processing
    content = result[:content]
    
    # User variables
    assert_match @user.first_name, content
    assert_match @user.last_name, content
    
    # Security variables
    assert_match 'New Browser Sign-in', content
    assert_match '192.168.1.100', content
    assert_match 'San Francisco, CA, US', content
    assert_match 'Mozilla/5.0', content
    assert_match 'Desktop Computer', content
    assert_match 'macOS', content
    assert_match 'Low', content
    assert_match 'December 25, 2023 at 02:30 PM', content
    
    # Ensure no template variables remain unprocessed
    assert_no_match /\{\{user\.\w+\}\}/, content, "User template variables not fully processed"
    assert_no_match /\{\{security\.\w+\}\}/, content, "Security template variables not fully processed"
  end

  test "handles missing security data gracefully" do
    data = {
      user: @user,
      # Only provide some security data
      event_type: 'Login Attempt',
      ip_address: '10.0.0.1'
      # Missing: browser_info, location, sign_in_time, device_type, os_info, risk_level
    }

    result = @template.render_content(data)
    
    # Should process available data
    assert_match 'Login Attempt', result[:content]
    assert_match '10.0.0.1', result[:content]
    
    # Should leave missing template variables unprocessed (as expected behavior)
    assert_match '{{security.browser_info}}', result[:content]
    assert_match '{{security.location}}', result[:content]
    assert_match '{{security.sign_in_time}}', result[:content]
  end

  test "processes timestamps in different formats correctly" do
    # Test with Time object
    time_obj = Time.new(2023, 6, 15, 9, 45, 0)
    data = { user: @user, sign_in_time: time_obj }
    
    result = @template.render_content(data)
    assert_match 'June 15, 2023 at 09:45 AM', result[:content]
    
    # Test with string that can't be parsed
    data = { user: @user, sign_in_time: 'invalid-time-string' }
    result = @template.render_content(data)
    assert_match 'invalid-time-string', result[:content]
  end

  test "case insensitive template variable matching" do
    # Create template with mixed case variables
    template = EmailTemplate.create!(
      name: 'Case Test Template',
      template_type: 'security_notification',
      subject: 'Alert for {{USER.FIRST_NAME}}',
      description: 'Test case sensitivity',
      content: '{{User.First_Name}} - {{SECURITY.EVENT_TYPE}} - {{security.IP_ADDRESS}}'
    )

    data = {
      user: @user,
      event_type: 'Test Event',
      ip_address: '127.0.0.1'
    }

    result = template.render_content(data)
    
    # Should match regardless of case
    assert_equal "Alert for #{@user.first_name}", result[:subject]
    assert_match @user.first_name, result[:content]
    assert_match 'Test Event', result[:content]
    assert_match '127.0.0.1', result[:content]
  ensure
    template&.destroy
  end

  test "available_fields includes all security notification fields" do
    available_fields = EmailTemplate.available_fields['security_notification']
    
    # Check user fields
    assert_includes available_fields['user'], 'first_name'
    assert_includes available_fields['user'], 'last_name'
    assert_includes available_fields['user'], 'full_name'
    assert_includes available_fields['user'], 'email'
    
    # Check security fields
    security_fields = available_fields['security']
    assert_includes security_fields, 'browser_info'
    assert_includes security_fields, 'ip_address'
    assert_includes security_fields, 'location'
    assert_includes security_fields, 'sign_in_time'
    assert_includes security_fields, 'event_type'
    assert_includes security_fields, 'device_type'
    assert_includes security_fields, 'os_info'
    assert_includes security_fields, 'risk_level'
  end

  test "template variables are processed in both subject and content" do
    template = EmailTemplate.create!(
      name: 'Both Fields Test',
      template_type: 'security_notification',
      subject: '{{security.event_type}} for {{user.email}}',
      description: 'Test both fields processing',
      content: 'User {{user.first_name}} had {{security.event_type}} from {{security.location}}'
    )

    data = {
      user: @user,
      event_type: 'Suspicious Login',
      location: 'Unknown Location'
    }

    result = template.render_content(data)
    
    # Subject should be processed
    assert_equal "Suspicious Login for #{@user.email}", result[:subject]
    
    # Content should be processed  
    expected_content = "User #{@user.first_name} had Suspicious Login from Unknown Location"
    assert_equal expected_content, result[:content]
  ensure
    template&.destroy
  end

  test "empty or nil data values are handled properly" do
    data = {
      user: @user,
      browser_info: nil,
      ip_address: '',
      location: '   ',  # whitespace only
      event_type: 'Test Event'
    }

    result = @template.render_content(data)
    
    # Should process non-nil/non-empty values
    assert_match 'Test Event', result[:content]
    assert_match @user.first_name, result[:content]
    
    # Should leave template variables for nil/empty values unprocessed
    assert_match '{{security.browser_info}}', result[:content]
    assert_match '{{security.ip_address}}', result[:content] 
    assert_match '{{security.location}}', result[:content]
  end

  test "large data values are processed correctly" do
    large_browser_info = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59 ' * 10
    
    data = {
      user: @user,
      browser_info: large_browser_info,
      event_type: 'Long Browser String Test'
    }

    result = @template.render_content(data)
    
    # Should handle large strings without truncation or error
    assert_match large_browser_info, result[:content]
    assert_match 'Long Browser String Test', result[:content]
  end

  test "special characters in data are handled safely" do
    data = {
      user: @user,
      browser_info: '<script>alert("xss")</script>',
      ip_address: '192.168.1.1 & echo "test"',
      location: 'City with "quotes" and <tags>',
      event_type: 'XSS & Injection Test'
    }

    result = @template.render_content(data)
    
    # Should process the data as-is (EmailTemplate doesn't sanitize - that's the view layer's job)
    assert_match '<script>alert("xss")</script>', result[:content]
    assert_match '192.168.1.1 & echo "test"', result[:content]
    assert_match 'City with "quotes" and <tags>', result[:content]
    assert_match 'XSS & Injection Test', result[:content]
  end
end