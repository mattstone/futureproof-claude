require 'test_helper'

class SecurityTemplateFieldSubstitutionTest < ActiveSupport::TestCase
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

    @template = EmailTemplate.create!(
      name: 'Security Test Template',
      template_type: 'security_notification',
      subject: 'Security Alert: {{security.event_type}} from {{security.location}}',
      content: <<~HTML
        <h1>Security Alert for {{user.first_name}}</h1>
        <p>Details:</p>
        <ul>
          <li>Time: {{security.sign_in_time}}</li>
          <li>IP Address: {{security.ip_address}}</li>
          <li>Location: {{security.location}}</li>
          <li>Browser: {{security.browser_info}}</li>
          <li>Device: {{security.device_type}}</li>
          <li>OS: {{security.os_info}}</li>
          <li>Risk Level: {{security.risk_level}}</li>
          <li>Event Type: {{security.event_type}}</li>
        </ul>
      HTML
    )
  end

  test "renders security template with all fields provided" do
    sign_in_time = Time.current
    data = {
      user: @user,
      browser_info: 'Chrome 120.0 on macOS',
      ip_address: '192.168.1.100',
      location: 'Sydney, NSW, Australia',
      sign_in_time: sign_in_time,
      event_type: 'New Browser Sign-in',
      device_type: 'Desktop Computer',
      os_info: 'macOS',
      risk_level: 'Low'
    }

    result = @template.render_content(data)

    # Subject should have substitutions
    assert_equal 'Security Alert: New Browser Sign-in from Sydney, NSW, Australia', result[:subject]

    # Content should have all substitutions
    content = result[:content]
    assert_includes content, 'Security Alert for John'
    assert_includes content, 'Time: ' + sign_in_time.strftime("%B %d, %Y at %I:%M %p")
    assert_includes content, 'IP Address: 192.168.1.100'
    assert_includes content, 'Location: Sydney, NSW, Australia'
    assert_includes content, 'Browser: Chrome 120.0 on macOS'
    assert_includes content, 'Device: Desktop Computer'
    assert_includes content, 'OS: macOS'
    assert_includes content, 'Risk Level: Low'
    assert_includes content, 'Event Type: New Browser Sign-in'
  end

  test "renders security template with nil location" do
    data = {
      user: @user,
      browser_info: 'Chrome 120.0 on macOS',
      ip_address: '127.0.0.1',
      location: nil,
      sign_in_time: Time.current,
      event_type: 'New Browser Sign-in',
      device_type: 'Desktop Computer',
      os_info: 'macOS',
      risk_level: 'Low'
    }

    result = @template.render_content(data)

    # Subject should use fallback for location
    assert_equal 'Security Alert: New Browser Sign-in from Unknown Location', result[:subject]

    # Content should use fallback
    assert_includes result[:content], 'Location: Unknown Location'
  end

  test "renders security template with all nil security fields" do
    data = {
      user: @user,
      browser_info: nil,
      ip_address: nil,
      location: nil,
      sign_in_time: nil,
      event_type: nil,
      device_type: nil,
      os_info: nil,
      risk_level: nil
    }

    result = @template.render_content(data)

    # Subject should use fallbacks
    assert_equal 'Security Alert: Sign-in Activity from Unknown Location', result[:subject]

    # Content should use all fallbacks
    content = result[:content]
    assert_includes content, 'Security Alert for John'
    assert_includes content, 'IP Address: Unknown IP'
    assert_includes content, 'Location: Unknown Location'
    assert_includes content, 'Browser: Unknown Browser'
    assert_includes content, 'Device: Unknown Device'
    assert_includes content, 'OS: Unknown OS'
    assert_includes content, 'Risk Level: Unknown'
    assert_includes content, 'Event Type: Sign-in Activity'
    
    # Should have current time as fallback
    current_time_formatted = Time.current.strftime("%B %d, %Y at %I:%M %p")
    assert_includes content, "Time: #{current_time_formatted}"
  end

  test "renders security template with empty string values" do
    data = {
      user: @user,
      browser_info: '',
      ip_address: '',
      location: '',
      sign_in_time: Time.current,
      event_type: '',
      device_type: '',
      os_info: '',
      risk_level: ''
    }

    result = @template.render_content(data)

    # Empty strings should be treated as absent and use fallbacks
    content = result[:content]
    assert_includes content, 'IP Address: Unknown IP'
    assert_includes content, 'Location: Unknown Location'
    assert_includes content, 'Browser: Unknown Browser'
    assert_includes content, 'Device: Unknown Device'
    assert_includes content, 'OS: Unknown OS'
    assert_includes content, 'Risk Level: Unknown'
    assert_includes content, 'Event Type: Sign-in Activity'
  end

  test "handles complex browser info extraction" do
    data = {
      user: @user,
      browser_info: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
      ip_address: '203.0.113.1',
      location: 'Melbourne, Victoria, Australia',
      sign_in_time: Time.current,
      event_type: 'New Browser Sign-in',
      device_type: 'Desktop Computer',
      os_info: 'macOS',
      risk_level: 'Medium'
    }

    result = @template.render_content(data)
    
    # Should include the full browser string
    assert_includes result[:content], 'Browser: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  end

  test "handles special characters in location" do
    data = {
      user: @user,
      browser_info: 'Chrome 120.0',
      ip_address: '198.51.100.1',
      location: 'São Paulo, São Paulo, Brazil',
      sign_in_time: Time.current,
      event_type: 'New Browser Sign-in',
      device_type: 'Mobile Device',
      os_info: 'Android',
      risk_level: 'Low'
    }

    result = @template.render_content(data)
    
    # Should handle UTF-8 characters properly
    assert_includes result[:content], 'Location: São Paulo, São Paulo, Brazil'
    assert_includes result[:subject], 'from São Paulo, São Paulo, Brazil'
  end

  test "maintains HTML structure with substitutions" do
    data = {
      user: @user,
      browser_info: 'Firefox 119.0',
      ip_address: '203.0.113.50',
      location: 'Toronto, Ontario, Canada',
      sign_in_time: Time.current,
      event_type: 'New Browser Sign-in',
      device_type: 'Desktop Computer',
      os_info: 'Windows',
      risk_level: 'Low'
    }

    result = @template.render_content(data)
    
    # Should maintain proper HTML structure
    assert_includes result[:content], '<h1>Security Alert for John</h1>'
    assert_includes result[:content], '<ul>'
    assert_includes result[:content], '</ul>'
    assert_includes result[:content], '<li>Time:'
    assert_includes result[:content], '</li>'
  end

  test "no placeholder remains unsubstituted in security fields" do
    data = {
      user: @user,
      # Minimal data to test fallbacks
      sign_in_time: Time.current
    }

    result = @template.render_content(data)

    # Should not have any unreplaced security placeholders
    assert_not_includes result[:subject], '{{security.'
    assert_not_includes result[:content], '{{security.'
    assert_not_includes result[:content], '{{user.'
  end

  test "date formatting works correctly" do
    specific_time = Time.new(2024, 12, 15, 14, 30, 0)
    data = {
      user: @user,
      browser_info: 'Chrome 120.0',
      ip_address: '198.51.100.1',
      location: 'New York, NY, USA',
      sign_in_time: specific_time,
      event_type: 'New Browser Sign-in'
    }

    result = @template.render_content(data)
    
    # Should format the date properly
    expected_time = 'December 15, 2024 at 02:30 PM'
    assert_includes result[:content], "Time: #{expected_time}"
  end

  test "handles malformed time gracefully" do
    data = {
      user: @user,
      browser_info: 'Chrome 120.0',
      ip_address: '198.51.100.1',
      location: 'London, England, UK',
      sign_in_time: 'invalid-time-string',
      event_type: 'New Browser Sign-in'
    }

    result = @template.render_content(data)
    
    # Should fallback to string representation if time formatting fails
    assert_includes result[:content], 'Time: invalid-time-string'
  end
end