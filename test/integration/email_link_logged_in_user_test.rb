require 'test_helper'

class EmailLinkLoggedInUserTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications

  def setup
    @user = users(:john)
    @application = applications(:submitted_application)
    @application.update!(user: @user)
    
    # Create a test message
    @message = ApplicationMessage.create!(
      application: @application,
      subject: "Test Message from Admin",
      content: "This is a test message.",
      sender: users(:admin_user),
      message_type: 'admin_to_customer',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    # Generate a valid token for the message
    @token = generate_valid_token(@application, @user, @message)
  end

  test "should redirect logged-in user directly to application messages when clicking email link" do
    # First, log in the user
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    assert_redirected_to dashboard_path
    follow_redirect!
    
    # Now click the email link while logged in
    get messages_application_path(@application, token: @token, message_id: @message.id)
    
    # Should go directly to the messages page, not to login
    assert_response :success
    
    # Should show the specific message highlighted
    assert_select ".message-thread.highlighted#message-#{@message.id}"
    assert_select "#message-#{@message.id} .message-subject", text: @message.subject
    
    # Should not have any pending session data since user went directly
    assert_nil session[:pending_message_access]
  end

  test "should redirect logged-in user to messages page without message_id parameter" do
    # Log in the user
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Click email link without message_id
    get messages_application_path(@application, token: @token)
    
    # Should go directly to messages page
    assert_response :success
    
    # Should not have any highlighted messages
    assert_select ".message-thread.highlighted", count: 0
    
    # Should show the message but not highlighted
    assert_select ".message-thread#message-#{@message.id}"
  end

  test "should redirect to login if token is for different user than logged-in user" do
    other_user = users(:jane)
    
    # Log in as different user
    post user_session_path, params: {
      user: { email: other_user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Try to access link for @user (different from logged-in user)
    get messages_application_path(@application, token: @token, message_id: @message.id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_path
    assert_equal 'Please log in to access your message.', flash[:notice]
    
    # Should store pending access for the correct user
    follow_redirect!
    assert session[:pending_message_access].present?
    assert_equal @user.id, session[:pending_message_access]['user_id']
  end

  test "should handle expired token for logged-in user" do
    # Log in the user
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Generate expired token
    expired_token = generate_expired_token(@application, @user, @message)
    
    # Try to access with expired token
    get messages_application_path(@application, token: expired_token, message_id: @message.id)
    
    # Should redirect to login with error
    assert_redirected_to new_user_session_path
    assert_equal 'This link has expired. Please log in to access your messages.', flash[:alert]
  end

  test "should handle invalid token for logged-in user" do
    # Log in the user  
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Try with invalid token
    get messages_application_path(@application, token: 'invalid-token', message_id: @message.id)
    
    # Should redirect to login with error
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
  end

  test "should allow access to own application without token when logged in" do
    # Log in the user
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Access messages without token (normal authenticated access)
    get messages_application_path(@application)
    
    # Should work normally
    assert_response :success
    assert_select ".message-thread#message-#{@message.id}"
  end

  test "should not allow access to other user's application even when logged in" do
    other_user = users(:jane)
    other_application = applications(:second_application)
    # Ensure it belongs to jane
    assert_equal other_user, other_application.user
    
    # Log in as @user (john)
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Try to access jane's application as john - should get 404
    get messages_application_path(other_application)
    assert_response :not_found
  end

  private

  def generate_valid_token(application, user, message)
    payload = {
      application_id: application.id,
      user_id: user.id,
      expires_at: 24.hours.from_now.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end

  def generate_expired_token(application, user, message)
    payload = {
      application_id: application.id,
      user_id: user.id,
      expires_at: 1.hour.ago.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end