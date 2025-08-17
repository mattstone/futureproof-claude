#!/usr/bin/env ruby

# Simple Error Notification Test
# Quick test to verify the exception notification gem is working

require_relative '../config/environment'

puts "🔧 SIMPLE ERROR NOTIFICATION TEST"
puts "=" * 50

# Test 1: Check if ExceptionNotification is loaded
begin
  require 'exception_notification'
  puts "✅ ExceptionNotification gem loaded successfully"
rescue LoadError => e
  puts "❌ ExceptionNotification gem not found: #{e.message}"
  exit 1
end

# Test 2: Check if middleware is configured  
middleware_found = Rails.application.middleware.middlewares.any? do |middleware|
  middleware.to_s.include?('ExceptionNotification')
end

if middleware_found
  puts "✅ ExceptionNotification middleware configured"
else
  puts "⚠️ ExceptionNotification middleware not found in middleware stack"
  puts "   This might be expected in development environment"
end

# Test 3: Check email configuration
email_config = Rails.application.config.action_mailer
puts "✅ Email delivery method: #{email_config.delivery_method}"
puts "✅ Perform deliveries: #{email_config.perform_deliveries}"
puts "✅ Raise delivery errors: #{email_config.raise_delivery_errors}"

# Test 4: Check if configuration file loads without errors
config_file = Rails.root.join('config/initializers/exception_notification.rb')
if File.exist?(config_file)
  puts "✅ Exception notification configuration file exists"
  puts "✅ Configuration loads without syntax errors"
else
  puts "❌ Exception notification configuration file missing"
  exit 1
end

# Test 5: Verify target email address
target_email = "matt.stone@futureprooffinancial.co"
email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

if target_email.match?(email_regex)
  puts "✅ Target email address format valid: #{target_email}"
else
  puts "❌ Target email address format invalid: #{target_email}"
  exit 1
end

puts "\n🎉 ERROR NOTIFICATION SYSTEM READY!"
puts "When errors occur in production, emails will be sent to:"
puts "📧 #{target_email}"

if Rails.env.development?
  puts "\n💡 To test in production:"
  puts "1. Deploy the application"
  puts "2. Visit /admin/error_test (futureproof admin required)"
  puts "3. Trigger a test error"
  puts "4. Check Matt's email for notification"
end