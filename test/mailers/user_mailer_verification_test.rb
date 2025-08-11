require 'test_helper'

class UserMailerVerificationTest < ActionMailer::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )
    @user.generate_verification_code
  end

  def teardown
    @user&.destroy
  end

  test "verification_code email is sent correctly" do
    email = UserMailer.verification_code(@user)
    
    # Test email headers
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal [@user.email], email.to
    assert_match(/verify/i, email.subject)
    assert_equal ["info@futureprooffinancial.co"], email.from
  end

  test "verification_code email contains verification code in body" do
    email = UserMailer.verification_code(@user)
    
    # Check that verification code appears in email body
    assert_match(@user.verification_code, email.body.encoded)
  end

  test "verification_code email uses template when available" do
    # Ensure there's an email template
    template = EmailTemplate.for_type('verification')
    assert_not_nil template, "Verification email template should exist"
    
    email = UserMailer.verification_code(@user)
    
    # Should use template system
    assert_not_nil email
    assert_match(@user.verification_code, email.body.encoded)
  end

  test "verification_code email falls back gracefully when template missing" do
    # Temporarily disable all email templates
    EmailTemplate.where(template_type: 'verification').update_all(is_active: false)
    
    email = UserMailer.verification_code(@user)
    
    # Should still send email with fallback
    assert_not_nil email
    assert_equal 'Verify Your Futureproof Account', email.subject
    assert_equal [@user.email], email.to
    
    # Re-enable templates for other tests
    EmailTemplate.where(template_type: 'verification').update_all(is_active: true)
  end

  test "verification_code email handles missing verification code gracefully" do
    # User without verification code
    user_without_code = User.create!(
      email: 'nocode@example.com',
      password: 'password123',
      first_name: 'No',
      last_name: 'Code',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil,
      verification_code: nil
    )

    # Should not raise error
    assert_nothing_raised do
      email = UserMailer.verification_code(user_without_code)
      assert_not_nil email
    end

    user_without_code.destroy
  end

  test "verification_code email includes expiration information" do
    email = UserMailer.verification_code(@user)
    
    # Should mention expiration in the email
    email_body = email.body.encoded
    assert_match(/expire/i, email_body)
    # Email template shows actual expiration time instead of "15 minutes"
    assert_match(/\d{1,2}:\d{2}\s*(AM|PM)/i, email_body)
  end

  test "verification_code is properly formatted in email" do
    email = UserMailer.verification_code(@user)
    email_body = email.body.encoded
    
    # Verification code should be prominently displayed
    assert_match(@user.verification_code, email_body)
    
    # Should be 6 digits
    assert_match(/^\d{6}$/, @user.verification_code)
  end

  test "multiple verification emails can be sent" do
    # Send first email
    email1 = UserMailer.verification_code(@user)
    first_code = @user.verification_code
    
    # Generate new code
    @user.generate_verification_code
    second_code = @user.verification_code
    
    # Send second email
    email2 = UserMailer.verification_code(@user)
    
    # Codes should be different
    assert_not_equal first_code, second_code
    
    # Both emails should be valid
    assert_not_nil email1
    assert_not_nil email2
    
    # Second email should have the new code
    assert_match(second_code, email2.body.encoded)
  end
end