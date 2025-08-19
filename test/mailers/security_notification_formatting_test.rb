#!/usr/bin/env ruby

# Security notification email formatting test
# Tests browser info formatting and email padding/styling

require_relative '../test_helper'

class SecurityNotificationFormattingTest < ActionMailer::TestCase
  def setup
    @user = User.new(
      email: 'test@example.com',
      first_name: 'John',
      last_name: 'Doe'
    )
  end

  test 'browser name formatting works correctly' do
    test_cases = [
      { input: 'Google Chrome 120.0.6099.109', expected: 'Google Chrome' },
      { input: 'Mozilla Firefox 119.0', expected: 'Mozilla Firefox' },
      { input: 'Safari 17.1.2', expected: 'Safari' },
      { input: 'Microsoft Edge 119.0.2151.97', expected: 'Microsoft Edge' },
      { input: 'Opera 105.0.4970.21', expected: 'Opera' },
      { input: 'Unknown Browser', expected: 'Unknown Browser' },
      { input: nil, expected: 'Unknown Browser' }
    ]

    test_cases.each do |test_case|
      browser_info = { 'browser' => test_case[:input] }
      
      mail = UserMailer.security_notification(
        @user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      assert_includes mail.body.encoded, test_case[:expected],
        "Browser '#{test_case[:input]}' should format to '#{test_case[:expected]}'"
    end
  end

  test 'platform name formatting works correctly' do
    test_cases = [
      { input: 'macOS 14.2.1', expected: 'macOS' },
      { input: 'Windows NT 10.0', expected: 'Windows' },
      { input: 'Linux x86_64', expected: 'Linux' },
      { input: 'Android 14', expected: 'Android' },
      { input: 'iPhone OS 17_1_2', expected: 'iOS' },
      { input: 'iPad OS 17_1_2', expected: 'iOS' },
      { input: 'Unix', expected: 'Unix' },
      { input: 'Unknown Platform', expected: 'Unknown Platform' },
      { input: nil, expected: 'Unknown Operating System' }
    ]

    test_cases.each do |test_case|
      browser_info = { 'platform' => test_case[:input] }
      
      mail = UserMailer.security_notification(
        @user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      assert_includes mail.body.encoded, test_case[:expected],
        "Platform '#{test_case[:input]}' should format to '#{test_case[:expected]}'"
    end
  end

  test 'language formatting works correctly' do
    test_cases = [
      { input: 'en-US', expected: 'English' },
      { input: 'en-GB', expected: 'English' },
      { input: 'es-ES', expected: 'Spanish' },
      { input: 'fr-FR', expected: 'French' },
      { input: 'de-DE', expected: 'German' },
      { input: 'it-IT', expected: 'Italian' },
      { input: 'pt-BR', expected: 'Portuguese' },
      { input: 'zh-CN', expected: 'Chinese' },
      { input: 'ja-JP', expected: 'Japanese' },
      { input: 'ko-KR', expected: 'Korean' },
      { input: 'ru-RU', expected: 'Russian' },
      { input: 'ar-SA', expected: 'Arabic' },
      { input: 'hi-IN', expected: 'Hindi' },
      { input: 'unknown-lang', expected: 'UNKNOWN-LANG' },
      { input: nil, expected: 'Unknown Language' }
    ]

    test_cases.each do |test_case|
      browser_info = { 'language' => test_case[:input] }
      
      mail = UserMailer.security_notification(
        @user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      assert_includes mail.body.encoded, test_case[:expected],
        "Language '#{test_case[:input]}' should format to '#{test_case[:expected]}'"
    end
  end

  test 'device type detection works correctly' do
    test_cases = [
      { 
        browser_info: { 'browser' => 'Chrome Mobile', 'platform' => 'Android' },
        expected: 'Mobile Device'
      },
      { 
        browser_info: { 'browser' => 'Safari', 'platform' => 'iPhone OS' },
        expected: 'Mobile Device'
      },
      { 
        browser_info: { 'browser' => 'Safari', 'platform' => 'iPad OS' },
        expected: 'Tablet'
      },
      { 
        browser_info: { 'browser' => 'Chrome', 'platform' => 'macOS' },
        expected: 'Desktop Computer'
      },
      { 
        browser_info: { 'browser' => 'Firefox', 'platform' => 'Windows' },
        expected: 'Desktop Computer'
      }
    ]

    test_cases.each do |test_case|
      mail = UserMailer.security_notification(
        @user,
        'test_signature',
        test_case[:browser_info],
        '127.0.0.1',
        'Test Location'
      )

      assert_includes mail.body.encoded, test_case[:expected],
        "Browser info '#{test_case[:browser_info]}' should detect device as '#{test_case[:expected]}'"
    end
  end

  test 'email contains proper padding and styling' do
    browser_info = {
      'browser' => 'Google Chrome 120.0.6099.109',
      'platform' => 'macOS 14.2.1',
      'language' => 'en-US'
    }
    
    mail = UserMailer.security_notification(
      @user,
      'test_signature',
      browser_info,
      '203.0.113.42',
      'Sydney, Australia'
    )

    body = mail.body.encoded

    # Check for proper padding styles
    assert_includes body, 'padding: 32px', 'Outer container should have 32px padding'
    assert_includes body, 'padding: 20px', 'Inner white box should have 20px padding'
    assert_includes body, 'padding: 16px 20px', 'Table cells should have 16px/20px padding'

    # Check for proper styling
    assert_includes body, 'background-color: #f8fafc', 'Should have light blue background'
    assert_includes body, 'border: 2px solid #e5e7eb', 'Should have border around main box'
    assert_includes body, 'background-color: #ffffff', 'Inner box should be white'
    assert_includes body, 'border-radius: 6px', 'Inner box should have rounded corners'

    # Check for proper content sections
    assert_includes body, 'Sign-in Details:', 'Should have sign-in details header'
    assert_includes body, 'Time:', 'Should show time field'
    assert_includes body, 'Browser:', 'Should show browser field'
    assert_includes body, 'Operating System:', 'Should show OS field'
    assert_includes body, 'Language:', 'Should show language field'
    assert_includes body, 'Device Type:', 'Should show device type field'
    assert_includes body, 'IP Address:', 'Should show IP address field'
    assert_includes body, 'Location:', 'Should show location field'
  end

  test 'email handles missing or nil browser info gracefully' do
    # Test with completely nil browser_info
    mail = UserMailer.security_notification(
      @user,
      'test_signature',
      nil,
      '127.0.0.1',
      'Test Location'
    )

    body = mail.body.encoded
    assert_includes body, 'Unknown Browser'
    assert_includes body, 'Unknown Operating System'
    assert_includes body, 'Unknown Language'
    assert_includes body, 'Desktop Computer' # Default device type

    # Test with empty hash
    mail = UserMailer.security_notification(
      @user,
      'test_signature',
      {},
      '127.0.0.1',
      'Test Location'
    )

    body = mail.body.encoded
    assert_includes body, 'Unknown Browser'
    assert_includes body, 'Unknown Operating System'
    assert_includes body, 'Unknown Language'

    # Test with partial data
    browser_info = { 'browser' => 'Chrome' }
    mail = UserMailer.security_notification(
      @user,
      'test_signature',
      browser_info,
      nil, # No IP
      nil  # No location
    )

    body = mail.body.encoded
    assert_includes body, 'Google Chrome'
    assert_includes body, 'Unknown Operating System'
    assert_includes body, 'Unknown Language'
    assert_not_includes body, 'IP Address:', 'Should not show IP section when nil'
    assert_not_includes body, 'Location:', 'Should not show location section when nil'
  end

  test 'email subject and basic structure' do
    browser_info = { 'browser' => 'Chrome', 'platform' => 'Windows', 'language' => 'en' }
    
    mail = UserMailer.security_notification(
      @user,
      'test_signature',
      browser_info,
      '127.0.0.1',
      'Test Location'
    )

    assert_equal 'Security Alert: Sign-in from New Browser', mail.subject
    assert_equal [@user.email], mail.to
    assert_equal ['info@futureprooffinancial.co'], mail.from

    body = mail.body.encoded
    assert_includes body, 'Security Alert'
    assert_includes body, 'New Browser Sign-in Detected'
    assert_includes body, 'Hello John'
    assert_includes body, 'Was this you?'
    assert_includes body, 'Change Password'
    assert_includes body, 'Contact Support'
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  require 'minitest/autorun'
  puts "🧪 Running Security Notification Email Formatting Tests..."
  
  # Create a simple test runner
  test_suite = SecurityNotificationFormattingTest.new
  
  methods = SecurityNotificationFormattingTest.instance_methods.select { |m| m.to_s.start_with?('test_') }
  
  puts "Found #{methods.length} test methods:"
  methods.each { |method| puts "  - #{method}" }
  
  puts "\n🚀 Run with: ruby test/mailers/security_notification_formatting_test.rb"
  puts "🚀 Or: rails test test/mailers/security_notification_formatting_test.rb"
end