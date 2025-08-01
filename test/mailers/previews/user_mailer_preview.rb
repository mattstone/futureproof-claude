# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/verification_code
  def verification_code
    user = User.first || User.new(email: "test@example.com", first_name: "John", last_name: "Doe")
    user.verification_code = "123456"
    user.verification_code_expires_at = 15.minutes.from_now
    UserMailer.verification_code(user)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/security_notification
  def security_notification
    user = User.first || User.new(email: "test@example.com", first_name: "John", last_name: "Doe")
    browser_signature = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
    browser_info = {
      'browser' => 'Google Chrome',
      'platform' => 'macOS',
      'language' => 'en-US'
    }
    ip_address = "203.0.113.42"
    location = "Sydney, New South Wales, Australia"
    UserMailer.security_notification(user, browser_signature, browser_info, ip_address, location)
  end
end
