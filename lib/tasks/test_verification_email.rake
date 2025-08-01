namespace :test do
  desc "Send a test verification code email"
  task verification_email: :environment do
    puts "Sending test verification code email..."
    
    # Create or use an existing user
    user = User.first
    
    if user.nil?
      user = User.create!(
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "User",
        country_of_residence: "Australia"
      )
    else
      # Update existing user with required fields if missing
      user.update!(
        first_name: "Test",
        last_name: "User"
      ) if user.first_name.blank? || user.last_name.blank?
    end
    
    # Set verification code directly
    user.verification_code = "123456"
    user.verification_code_expires_at = 15.minutes.from_now
    user.save!(validate: false)
    
    # Send the verification code email
    UserMailer.verification_code(user).deliver_now
    
    puts "Test verification code email sent to #{user.email}"
    puts "Check your browser - letter_opener should have opened the email automatically!"
  end
end