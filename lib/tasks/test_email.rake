namespace :test do
  desc "Send a test security notification email"
  task security_email: :environment do
    puts "Sending test security notification email..."
    
    # Create or use an existing user
    user = User.first || User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User",
      country_of_residence: "Australia"
    )
    
    # Sample browser signature and info
    browser_signature = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
    browser_info = {
      'browser' => 'Google Chrome',
      'platform' => 'macOS',
      'language' => 'en-US'
    }
    
    # Sample IP address and location
    ip_address = "203.0.113.42"  # Example IP (documentation range)
    location = "Sydney, New South Wales, Australia"
    
    # Send the security notification email
    UserMailer.security_notification(user, browser_signature, browser_info, ip_address, location).deliver_now
    
    puts "Test security notification email sent to #{user.email}"
    puts "Check your browser - letter_opener should have opened the email automatically!"
  end
end