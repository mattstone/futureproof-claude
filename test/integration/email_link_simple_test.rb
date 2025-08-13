require 'test_helper'

class EmailLinkSimpleTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications

  def setup
    # Create a memory cache for these tests
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:john)
    @application = applications(:submitted_application)
    @application.update!(user: @user)
    
    # Create a test message
    @message = ApplicationMessage.create!(
      application: @application,
      subject: "Test Message",
      content: "Test content",
      sender: users(:admin_user),
      message_type: 'admin_to_customer',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    @token = generate_valid_token(@application, @user, @message)
  end
  
  def teardown
    # Restore original cache
    Rails.cache = @original_cache
  end

  test "email link stores intended path and redirects to login" do
    # Click email link
    get messages_application_path(@application, token: @token, message_id: @message.id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_path
    assert_equal 'Please log in to access your message.', flash[:notice]
    
    follow_redirect!
    
    # Should store the intended dashboard path in cache
    cache_key = "user_#{@user.id}_pending_redirect"
    cached_path = Rails.cache.read(cache_key)
    assert cached_path.present?, "Expected cached path to be present"
    expected_path = "#{dashboard_path}?section=applications&application_id=#{@application.id}"
    assert_equal expected_path, cached_path
  end

  test "login after email link redirects to dashboard with application expanded" do
    # First click email link to set up cache
    get messages_application_path(@application, token: @token, message_id: @message.id)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Then log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to dashboard with application section
    expected_path = "#{dashboard_path}?section=applications&application_id=#{@application.id}"
    assert_redirected_to expected_path
    
    # Cached path should be cleared after use
    cache_key = "user_#{@user.id}_pending_redirect"
    assert_nil Rails.cache.read(cache_key)
    
    # Follow the redirect to verify the page works
    follow_redirect!
    assert_response :success
    
    # Should show the dashboard with applications section
    assert_select "body"
  end

  test "login after email link without message_id redirects to dashboard" do
    # Click email link without message_id
    get messages_application_path(@application, token: @token)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to dashboard with application section
    expected_path = "#{dashboard_path}?section=applications&application_id=#{@application.id}"
    assert_redirected_to expected_path
    
    follow_redirect!
    assert_response :success
    
    # Should show the dashboard
    assert_select "body"
  end

  test "normal login without email link goes to dashboard" do
    # Normal login without any pending access
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should go to dashboard
    assert_redirected_to dashboard_path
  end

  test "token for wrong application redirects to login with error message" do
    # Create another application for a different user
    other_user = users(:jane)
    other_application = applications(:second_application)
    other_application.update!(user: other_user)
    
    # Generate token for other user's application but try to access current user's application
    token_for_other_application = generate_valid_token(other_application, other_user, @message)
    
    get messages_application_path(@application, token: token_for_other_application, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
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
end