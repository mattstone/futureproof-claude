require 'test_helper'

class EmailLinkAuthenticationTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications
  
  def setup
    @user = users(:john)
    @application = applications(:submitted_application)
    @application.update!(user: @user)
    
    # Create a test message
    @message = ApplicationMessage.create!(
      application: @application,
      subject: "Important Update About Your Application",
      content: "We have an important update regarding your mortgage application.",
      sender: users(:admin_user),
      message_type: 'admin_to_customer',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    # Generate a valid token for the message
    @token = generate_valid_token(@application, @user)
  end

  test "should redirect to login when accessing message link without authentication" do
    # Visit the message link without being logged in
    get messages_application_path(@application, token: @token, message_id: @message.id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_path
    assert_equal 'Please log in to access your message.', flash[:notice]
    
    # Should store pending message access in session
    follow_redirect!
    assert session[:pending_message_access].present?
    assert_equal @user.id, session[:pending_message_access]['user_id']
    assert_equal @application.id, session[:pending_message_access]['application_id']
    assert_equal @message.id.to_s, session[:pending_message_access]['message_id']
    assert session[:pending_message_access]['token_verified']
  end

  test "should redirect to specific message after successful login from email link" do
    # First, visit the message link to set up pending access
    get messages_application_path(@application, token: @token, message_id: @message.id)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Now log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to the specific message
    assert_redirected_to messages_application_path(@application, message_id: @message.id)
    
    # Session should be cleared
    assert_nil session[:pending_message_access]
    
    # Follow the redirect and verify we're on the right page
    follow_redirect!
    assert_response :success
    
    # Should show the specific message highlighted
    assert_select ".message-thread.highlighted#message-#{@message.id}"
    assert_select "#message-#{@message.id} .message-subject", text: @message.subject
  end

  test "should redirect to messages page without message_id when not provided in email link" do
    # Generate token without message_id parameter
    get messages_application_path(@application, token: @token)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to messages page without message_id
    assert_redirected_to messages_application_path(@application)
    
    follow_redirect!
    assert_response :success
    
    # Should not have any highlighted messages
    assert_select ".message-thread.highlighted", count: 0
  end

  test "should handle expired token gracefully" do
    # Generate an expired token
    expired_token = generate_expired_token(@application, @user)
    
    get messages_application_path(@application, token: expired_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'This link has expired. Please log in to access your messages.', flash[:alert]
    
    # Should not store pending access for expired token
    follow_redirect!
    assert_nil session[:pending_message_access]
  end

  test "should handle invalid token gracefully" do
    invalid_token = "invalid-token"
    
    get messages_application_path(@application, token: invalid_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
    
    # Should not store pending access for invalid token
    follow_redirect!
    assert_nil session[:pending_message_access]
  end

  test "should reject token for wrong user" do
    other_user = users(:admin_user) # Different user
    wrong_user_token = generate_valid_token(@application, other_user)
    
    get messages_application_path(@application, token: wrong_user_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
    
    # Should not store pending access
    follow_redirect!
    assert_nil session[:pending_message_access]
  end

  test "should reject token for wrong application" do
    other_application = applications(:second_application)
    wrong_app_token = generate_valid_token(other_application, @user)
    
    get messages_application_path(@application, token: wrong_app_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
  end

  test "should handle login for different user than token user" do
    # Set up pending access for one user
    get messages_application_path(@application, token: @token, message_id: @message.id)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Log in as different user
    other_user = users(:admin_user)
    post user_session_path, params: {
      user: { email: other_user.email, password: 'password123' }
    }
    
    # Should redirect to default dashboard (not the pending message)
    assert_redirected_to admin_root_path # admin user goes to admin
    
    # Session should still be there since wrong user logged in
    # (it only clears when the correct user logs in)
    assert session[:pending_message_access].present?
  end

  test "should clear expired pending access on login" do
    # Manually set expired pending access - need to use the integration test session properly
    get root_path  # Make sure we have a session
    
    # Simulate expired pending access by visiting an expired link
    expired_token = generate_expired_token(@application, @user)
    get messages_application_path(@application, token: expired_token, message_id: @message.id)
    
    # Should redirect to login with error (no pending access set)
    assert_redirected_to new_user_session_path
    assert_equal 'This link has expired. Please log in to access your messages.', flash[:alert]
    follow_redirect!
    
    # Now log in normally
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to default dashboard
    assert_redirected_to dashboard_path
  end

  test "should work with email verification flow" do
    # Make user unconfirmed
    @user.update!(confirmed_at: nil)
    
    # Visit message link
    get messages_application_path(@application, token: @token, message_id: @message.id)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Log in as unconfirmed user
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to email verification, not to message
    assert_redirected_to new_users_verification_path(email: @user.email)
    
    # Session should still be preserved for after verification
    assert session[:pending_message_access].present?
  end

  private

  def generate_valid_token(application, user)
    payload = {
      application_id: application.id,
      user_id: user.id,
      expires_at: 24.hours.from_now.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end

  def generate_expired_token(application, user)
    payload = {
      application_id: application.id,
      user_id: user.id,
      expires_at: 1.hour.ago.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end