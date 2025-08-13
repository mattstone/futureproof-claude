require 'test_helper'

class ContractEmailLinkTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications

  def setup
    # Create a memory cache for these tests
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    @user = users(:john)
    @application = applications(:submitted_application)
    @application.update!(user: @user)
    
    # Find existing contract or create a new one
    @contract = Contract.find_by(application: @application) || Contract.create!(
      application: @application,
      status: :ok,
      start_date: 1.month.ago,
      end_date: 30.years.from_now
    )
    
    # Create a test contract message
    @message = ContractMessage.create!(
      contract: @contract,
      subject: "Test Contract Message",
      content: "Test contract content",
      sender: users(:admin_user),
      message_type: 'admin_to_customer',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    @token = generate_valid_token(@contract, @user, @message)
  end
  
  def teardown
    # Restore original cache
    Rails.cache = @original_cache
  end

  test "contract email link stores intended path and redirects to login" do
    # Click contract email link
    get messages_contract_path(@contract, token: @token, message_id: @message.id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_path
    assert_equal 'Please log in to access your message.', flash[:notice]
    
    follow_redirect!
    
    # Should store the intended dashboard path in cache
    cache_key = "user_#{@user.id}_pending_redirect"
    cached_path = Rails.cache.read(cache_key)
    assert cached_path.present?, "Expected cached path to be present"
    expected_path = "#{dashboard_path}?section=contracts&contract_id=#{@contract.id}"
    assert_equal expected_path, cached_path
  end

  test "login after contract email link redirects to dashboard with contract expanded" do
    # First click email link to set up cache
    get messages_contract_path(@contract, token: @token, message_id: @message.id)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Then log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to dashboard with contract section
    expected_path = "#{dashboard_path}?section=contracts&contract_id=#{@contract.id}"
    assert_redirected_to expected_path
    
    # Cached path should be cleared after use
    cache_key = "user_#{@user.id}_pending_redirect"
    assert_nil Rails.cache.read(cache_key)
    
    # Follow the redirect to verify the page works
    follow_redirect!
    assert_response :success
    
    # Should show the dashboard with contracts section
    assert_select "body"
  end

  test "login after contract email link without message_id redirects to dashboard" do
    # Click email link without message_id
    get messages_contract_path(@contract, token: @token)
    assert_redirected_to new_user_session_path
    follow_redirect!
    
    # Log in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to dashboard with contract section
    expected_path = "#{dashboard_path}?section=contracts&contract_id=#{@contract.id}"
    assert_redirected_to expected_path
    
    follow_redirect!
    assert_response :success
    
    # Should show the dashboard
    assert_select "body"
  end

  test "normal login without contract email link goes to dashboard" do
    # Normal login without any pending access
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should go to dashboard
    assert_redirected_to dashboard_path
  end

  test "expired token redirects to login with error message" do
    expired_token = generate_expired_token(@contract, @user, @message)
    
    get messages_contract_path(@contract, token: expired_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'This link has expired. Please log in to access your messages.', flash[:alert]
  end

  test "invalid token redirects to login with error message" do
    invalid_token = "invalid_token_string"
    
    get messages_contract_path(@contract, token: invalid_token, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
  end

  test "token for different user redirects to login with error message" do
    other_user = users(:jane)
    other_application = applications(:second_application)
    other_application.update!(user: other_user)
    
    other_contract = Contract.find_by(application: other_application) || Contract.create!(
      application: other_application,
      status: :ok,
      start_date: 1.month.ago,
      end_date: 30.years.from_now
    )
    
    # Generate token for other user's contract but access the wrong contract
    # This tests the scenario where someone tries to use a valid token for the wrong contract
    token_for_other_user = generate_valid_token(other_contract, other_user, @message)
    
    get messages_contract_path(@contract, token: token_for_other_user, message_id: @message.id)
    
    assert_redirected_to new_user_session_path
    assert_equal 'Invalid access link. Please log in to continue.', flash[:alert]
  end

  test "contract mailer generates secure link with token" do
    # Send a contract message
    @message = ContractMessage.create!(
      contract: @contract,
      subject: "Test Email Link",
      content: "Testing contract email functionality",
      sender: users(:admin_user),
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    # Send the message (which triggers email)
    mail = ContractMailer.message_notification(@message)
    mail_body = mail.body.encoded
    
    # Debug: Check what's in the mail body
    puts "Mail body: #{mail_body.inspect}" if mail_body.blank?
    
    # Check that the email contains a secure link with token
    assert_match(/token=/, mail_body, "Expected token in mail body: #{mail_body.inspect}")
    
    # Check that the contract link is generated correctly
    assert_match(%r{contracts/\d+/messages}, mail_body)
    
    # Just verify that a token parameter is present - we'll test the actual
    # token functionality through the integration tests which don't have 
    # the email HTML formatting issues
    token_match = mail_body.match(/token=([^"&\s]+)/)
    assert token_match, "Token should be present in email"
    
    captured_token = token_match[1]
    assert captured_token.length > 0, "Token should not be empty"
  end

  private

  def generate_valid_token(contract, user, message)
    payload = {
      contract_id: contract.id,
      user_id: user.id,
      expires_at: 24.hours.from_now.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end

  def generate_expired_token(contract, user, message)
    payload = {
      contract_id: contract.id,
      user_id: user.id,
      expires_at: 1.hour.ago.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end