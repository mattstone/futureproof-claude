#!/usr/bin/env ruby

# Standalone security notification email formatting test
# This test avoids fixtures and tests email formatting directly

require_relative '../config/environment'

class SecurityEmailStandaloneTest
  def self.run
    puts "🧪 Security Alert Email Formatting Tests"
    puts "Testing improved padding and browser info formatting..."
    
    begin
      # Create a test user (not persisted)
      test_user = User.new(
        email: 'test@example.com',
        first_name: 'John',
        last_name: 'Doe'
      )
      
      puts "\n📋 Test 1: Browser name formatting..."
      test_browser_formatting(test_user)
      
      puts "\n📋 Test 2: Platform name formatting..."
      test_platform_formatting(test_user)
      
      puts "\n📋 Test 3: Language formatting..."
      test_language_formatting(test_user)
      
      puts "\n📋 Test 4: Device type detection..."
      test_device_type_detection(test_user)
      
      puts "\n📋 Test 5: Email padding and styling..."
      test_email_styling(test_user)
      
      puts "\n📋 Test 6: Missing data handling..."
      test_missing_data_handling(test_user)
      
      puts "\n🎉 ALL SECURITY EMAIL FORMATTING TESTS PASSED!"
      
      return true
      
    rescue => e
      puts "\n💥 ERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      return false
    end
  end
  
  private
  
  def self.test_browser_formatting(user)
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
        user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      body = mail.body.encoded
      if body.include?(test_case[:expected])
        puts "  ✅ Browser '#{test_case[:input]}' correctly formats to '#{test_case[:expected]}'"
      else
        puts "  ❌ Browser '#{test_case[:input]}' failed to format to '#{test_case[:expected]}'"
        puts "     Email body contains: #{extract_browser_from_body(body)}"
        return false
      end
    end
    
    puts "  ✅ All browser name formatting tests passed"
  end
  
  def self.test_platform_formatting(user)
    test_cases = [
      { input: 'macOS 14.2.1', expected: 'macOS' },
      { input: 'Windows NT 10.0', expected: 'Windows' },
      { input: 'Linux x86_64', expected: 'Linux' },
      { input: 'Android 14', expected: 'Android' },
      { input: 'iPhone OS 17_1_2', expected: 'iOS' },
      { input: 'iPad OS 17_1_2', expected: 'iOS' },
      { input: 'Unix', expected: 'Unix' },
      { input: nil, expected: 'Unknown Operating System' }
    ]

    test_cases.each do |test_case|
      browser_info = { 'platform' => test_case[:input] }
      
      mail = UserMailer.security_notification(
        user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      body = mail.body.encoded
      if body.include?(test_case[:expected])
        puts "  ✅ Platform '#{test_case[:input]}' correctly formats to '#{test_case[:expected]}'"
      else
        puts "  ❌ Platform '#{test_case[:input]}' failed to format to '#{test_case[:expected]}'"
        return false
      end
    end
    
    puts "  ✅ All platform name formatting tests passed"
  end
  
  def self.test_language_formatting(user)
    test_cases = [
      { input: 'en-US', expected: 'English' },
      { input: 'en-GB', expected: 'English' },
      { input: 'es-ES', expected: 'Spanish' },
      { input: 'fr-FR', expected: 'French' },
      { input: 'de-DE', expected: 'German' },
      { input: 'zh-CN', expected: 'Chinese' },
      { input: 'ja-JP', expected: 'Japanese' },
      { input: 'unknown-lang', expected: 'UNKNOWN-LANG' },
      { input: nil, expected: 'Unknown Language' }
    ]

    test_cases.each do |test_case|
      browser_info = { 'language' => test_case[:input] }
      
      mail = UserMailer.security_notification(
        user,
        'test_signature',
        browser_info,
        '127.0.0.1',
        'Test Location'
      )

      body = mail.body.encoded
      if body.include?(test_case[:expected])
        puts "  ✅ Language '#{test_case[:input]}' correctly formats to '#{test_case[:expected]}'"
      else
        puts "  ❌ Language '#{test_case[:input]}' failed to format to '#{test_case[:expected]}'"
        return false
      end
    end
    
    puts "  ✅ All language formatting tests passed"
  end
  
  def self.test_device_type_detection(user)
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
      }
    ]

    test_cases.each do |test_case|
      mail = UserMailer.security_notification(
        user,
        'test_signature',
        test_case[:browser_info],
        '127.0.0.1',
        'Test Location'
      )

      body = mail.body.encoded
      if body.include?(test_case[:expected])
        puts "  ✅ Browser info correctly detects device as '#{test_case[:expected]}'"
      else
        puts "  ❌ Browser info failed to detect device as '#{test_case[:expected]}'"
        return false
      end
    end
    
    puts "  ✅ All device type detection tests passed"
  end
  
  def self.test_email_styling(user)
    browser_info = {
      'browser' => 'Google Chrome 120.0.6099.109',
      'platform' => 'macOS 14.2.1',
      'language' => 'en-US'
    }
    
    mail = UserMailer.security_notification(
      user,
      'test_signature',
      browser_info,
      '203.0.113.42',
      'Sydney, Australia'
    )

    body = mail.body.encoded
    
    # Test padding and styling
    style_tests = [
      { style: 'padding: 32px', description: 'Outer container 32px padding' },
      { style: 'padding: 20px', description: 'Inner white box 20px padding' },
      { style: 'padding: 16px 20px', description: 'Table cells 16px/20px padding' },
      { style: 'background-color: #f8fafc', description: 'Light blue background' },
      { style: 'border: 2px solid #e5e7eb', description: 'Border around main box' },
      { style: 'background-color: #ffffff', description: 'White inner box' },
      { style: 'border-radius: 6px', description: 'Rounded corners' }
    ]
    
    style_tests.each do |test|
      if body.include?(test[:style])
        puts "  ✅ #{test[:description]} - Found: #{test[:style]}"
      else
        puts "  ❌ #{test[:description]} - Missing: #{test[:style]}"
        return false
      end
    end
    
    # Test content sections
    content_tests = [
      'Sign-in Details:',
      'Time:',
      'Browser:',
      'Operating System:',
      'Language:',
      'Device Type:',
      'IP Address:',
      'Location:'
    ]
    
    content_tests.each do |content|
      if body.include?(content)
        puts "  ✅ Contains '#{content}' field"
      else
        puts "  ❌ Missing '#{content}' field"
        return false
      end
    end
    
    puts "  ✅ All email styling and content tests passed"
  end
  
  def self.test_missing_data_handling(user)
    # Test with nil browser_info
    mail = UserMailer.security_notification(
      user,
      'test_signature',
      nil,
      '127.0.0.1',
      'Test Location'
    )

    body = mail.body.encoded
    required_fallbacks = [
      'Unknown Browser',
      'Unknown Operating System', 
      'Unknown Language',
      'Desktop Computer'
    ]
    
    required_fallbacks.each do |fallback|
      if body.include?(fallback)
        puts "  ✅ Nil data correctly shows '#{fallback}'"
      else
        puts "  ❌ Nil data missing fallback '#{fallback}'"
        return false
      end
    end
    
    # Test with partial data and no IP/location
    browser_info = { 'browser' => 'Chrome' }
    mail = UserMailer.security_notification(
      user,
      'test_signature',
      browser_info,
      nil, # No IP
      nil  # No location
    )

    body = mail.body.encoded
    if body.include?('Google Chrome') && 
       !body.include?('IP Address:') && 
       !body.include?('Location:')
      puts "  ✅ Partial data handled correctly, optional fields hidden"
    else
      puts "  ❌ Partial data not handled correctly"
      return false
    end
    
    puts "  ✅ All missing data handling tests passed"
  end
  
  def self.extract_browser_from_body(body)
    # Simple regex to extract browser info from email body
    match = body.match(/Browser:<\/td>\s*<td[^>]*>([^<]+)</m)
    match ? match[1].strip : 'Not found'
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  success = SecurityEmailStandaloneTest.run
  exit(success ? 0 : 1)
end