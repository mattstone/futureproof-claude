namespace :email do
  desc "Fix security email template and send test email"
  task fix_security_template: :environment do
    puts "Fixing security email template..."
    
    # Find or create the security notification template
    template = EmailTemplate.find_by(template_type: 'security_notification')
    
    if template
      puts "Found existing security notification template"
      # Check if it has incorrect placeholders
      if template.content.include?('{{sign_in_time}}') && !template.content.include?('{{security.sign_in_time}}')
        puts "Template has incorrect placeholders, fixing..."
        
        # Fix the template content with correct placeholders
        fixed_content = template.content.dup
        fixed_content.gsub!(/\{\{sign_in_time\}\}/, '{{security.sign_in_time}}')
        fixed_content.gsub!(/\{\{browser_info\}\}/, '{{security.browser_info}}')
        fixed_content.gsub!(/\{\{os_info\}\}/, '{{security.os_info}}')
        fixed_content.gsub!(/\{\{device_type\}\}/, '{{security.device_type}}')
        fixed_content.gsub!(/\{\{ip_address\}\}/, '{{security.ip_address}}')
        fixed_content.gsub!(/\{\{location\}\}/, '{{security.location}}')
        
        template.update!(content: fixed_content)
        puts "✓ Fixed security template placeholders"
      else
        puts "Template already has correct placeholders"
      end
    else
      puts "No template found, creating default template..."
      template = EmailTemplate.for_type('security_notification')
      puts "✓ Created default security notification template"
    end
    
    puts "Current template content preview:"
    puts template.content[0..200] + "..."
  end
  
  desc "Send test security email"
  task send_test_security: :environment do
    admin_user = User.where(admin: true).first
    
    if admin_user.nil?
      puts "No admin user found to send test email to"
      exit 1
    end
    
    puts "Sending test security email to #{admin_user.email}..."
    
    # Simulate realistic browser info
    browser_info = {
      'browser' => 'Chrome',
      'platform' => 'macOS',
      'language' => 'en-US',
      'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    
    # Send the security notification
    UserMailer.security_notification(
      admin_user,
      'test_browser_signature_' + Time.current.to_i.to_s,
      browser_info,
      '203.0.113.42', # Example IP address
      'Sydney, NSW, Australia'
    ).deliver_now
    
    puts "✓ Test security email sent successfully!"
    puts "Check your email at #{admin_user.email}"
    puts
    puts "Expected browser display: Google Chrome"
    puts "Expected OS display: macOS" 
    puts "Expected device type: Desktop Computer"
  end
  
  desc "Fix template and send test email"
  task fix_and_test: :environment do
    Rake::Task["email:fix_security_template"].invoke
    puts
    Rake::Task["email:send_test_security"].invoke
  end
end