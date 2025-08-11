require 'test_helper'

class VerificationEmailTest < ActionDispatch::IntegrationTest
  def setup
    # Clear any existing test users
    User.where(email: ['test-verification@example.com', 'test-resend@example.com']).destroy_all
    
    # Clear any emails from previous tests
    ActionMailer::Base.deliveries.clear
  end

  def teardown
    # Clean up test users
    User.where(email: ['test-verification@example.com', 'test-resend@example.com']).destroy_all
    
    # Clear emails
    ActionMailer::Base.deliveries.clear
  end

  test "verification email is sent when unverified user accesses verification page" do
    # Create unverified user
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Visit verification page
    get new_users_verification_path(email: user.email)
    
    # Should get success response
    assert_response :success
    
    # Should have sent verification email
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    # Check email content
    email = ActionMailer::Base.deliveries.last
    assert_equal user.email, email.to.first
    assert_match(/verify/i, email.subject)
    
    # Reload user to get updated verification code
    user.reload
    assert_not_nil user.verification_code
    assert_not_nil user.verification_code_expires_at
    assert user.verification_code_expires_at > Time.current
    
    # Check that email contains verification code
    assert_match(user.verification_code, email.body.to_s)
  end

  test "no email sent if user already has valid verification code" do
    # Create unverified user with existing valid code
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )
    
    # Generate initial verification code
    user.generate_verification_code
    original_code = user.verification_code
    
    # Clear emails from code generation
    ActionMailer::Base.deliveries.clear
    
    # Visit verification page
    get new_users_verification_path(email: user.email)
    
    # Should get success response
    assert_response :success
    
    # Should NOT have sent new email since code is still valid
    assert_equal 0, ActionMailer::Base.deliveries.size
    
    # Code should remain the same
    user.reload
    assert_equal original_code, user.verification_code
  end

  test "new email sent if existing verification code is expired" do
    # Create unverified user with expired code
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )
    
    # Generate expired verification code
    user.verification_code = '123456'
    user.verification_code_expires_at = 1.hour.ago  # Expired
    user.save!
    
    # Visit verification page
    get new_users_verification_path(email: user.email)
    
    # Should get success response
    assert_response :success
    
    # Should have sent new verification email
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    # User should have new verification code
    user.reload
    assert_not_equal '123456', user.verification_code
    assert user.verification_code_expires_at > Time.current
  end

  test "resend verification code sends new email" do
    # Create unverified user
    user = User.create!(
      email: 'test-resend@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'Resend',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Post to resend verification
    post resend_users_verifications_path, params: { email: user.email }
    
    # Should redirect back to verification page
    assert_redirected_to new_users_verification_path(email: user.email)
    assert_equal 'A new verification code has been sent to your email.', flash[:notice]
    
    # Should have sent verification email
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    # Check email
    email = ActionMailer::Base.deliveries.last
    assert_equal user.email, email.to.first
    
    # User should have new verification code
    user.reload
    assert_not_nil user.verification_code
    assert user.verification_code_expires_at > Time.current
  end

  test "unverified user redirected from dashboard gets verification email" do
    # Create unverified user  
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Sign in the user
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    
    # Should be redirected to verification page with email
    expected_redirect = new_users_verification_path(email: user.email)
    assert_redirected_to expected_redirect
    
    # Follow the redirect
    follow_redirect!
    assert_response :success
    
    # Should have sent verification email
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    email = ActionMailer::Base.deliveries.last
    assert_equal user.email, email.to.first
    assert_match(/verify/i, email.subject)
  end

  test "verification code email contains proper content and formatting" do
    # Create unverified user
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Visit verification page to trigger email
    get new_users_verification_path(email: user.email)
    
    # Check email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    email = ActionMailer::Base.deliveries.last
    user.reload
    
    # Check email headers
    assert_equal user.email, email.to.first
    assert_match(/verify/i, email.subject)
    
    # Check email body contains verification code
    email_body = email.body.to_s
    assert_match(user.verification_code, email_body)
    
    # Check for key content elements  
    assert_match(/verify/i, email_body)
    assert_match(/expires/i, email_body)
    
    # Verify code format (should be 6 digits)
    assert_match(/^\d{6}$/, user.verification_code)
    
    # Verify expiration time is set correctly (15 minutes from now)
    expected_expiration = 15.minutes.from_now
    time_diff = (user.verification_code_expires_at - expected_expiration).abs
    assert time_diff < 1.minute, "Expiration time should be approximately 15 minutes from now"
  end

  test "flash message shown when verification email is sent" do
    # Create unverified user
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Visit verification page
    get new_users_verification_path(email: user.email)
    
    # Should show flash message about email being sent
    assert_match(/verification code has been sent/i, flash[:notice])
  end

  test "no flash message if verification code already exists and is valid" do
    # Create unverified user with valid verification code
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )
    
    # Generate valid verification code
    user.generate_verification_code
    
    # Visit verification page
    get new_users_verification_path(email: user.email)
    
    # Should not show flash message since no new email was sent
    assert_nil flash[:notice]
  end
end