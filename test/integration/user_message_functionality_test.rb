require "test_helper"

class UserMessageFunctionalityTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user
    @admin = create_admin_user  
    @application = create_application_for_user(@user)
    @agent = create_ai_agent("Motoko", "applications", "Motoko.png")
  end
  
  test "user can access message page directly via secure token link" do
    # Create a message from admin
    message = create_admin_message(@application, @admin, @agent, "Welcome to your application")
    
    # Generate secure token (same as in mailer)
    payload = {
      application_id: @application.id,
      user_id: @user.id,
      expires_at: 24.hours.from_now.to_i
    }
    token = SecureTokenEncryptor.encrypt_and_sign(payload)
    
    # Visit the secure link (without being logged in)
    get messages_application_path(@application, token: token)
    
    assert_response :success
    assert_select "h1", text: "Messages"
    assert_select ".message-thread", count: 1
    assert_select ".message-subject h3", text: "Welcome to your application"
  end
  
  test "user can view message history when logged in" do
    sign_in @user
    
    # Create several messages
    message1 = create_admin_message(@application, @admin, @agent, "First message")
    message2 = create_admin_message(@application, @admin, @agent, "Second message") 
    message3 = create_admin_message(@application, @admin, @agent, "Third message")
    
    get messages_application_path(@application)
    
    assert_response :success
    
    # Should show all messages in descending order (newest first)
    assert_select ".message-threads .message-thread", count: 3
    message_subjects = css_select(".message-subject h3").map(&:text)
    assert_equal ["Third message", "Second message", "First message"], message_subjects
  end
  
  test "user can reply to admin messages" do
    sign_in @user
    
    # Create admin message
    admin_message = create_admin_message(@application, @admin, @agent, "How are you?")
    
    get messages_application_path(@application)
    assert_response :success
    
    # Post reply
    assert_difference "ApplicationMessage.count", 1 do
      post reply_to_message_application_path(@application), params: {
        application_message: {
          subject: "Re: How are you?",
          content: "I'm doing well, thank you!",
          parent_message_id: admin_message.id
        }
      }
    end
    
    assert_redirected_to messages_application_path(@application)
    follow_redirect!
    
    # Should show reply in the thread
    assert_select ".message-replies", count: 1
    assert_select ".reply-content", text: /I'm doing well, thank you!/
    
    # Check that reply is properly associated
    reply = ApplicationMessage.last
    assert_equal admin_message.id, reply.parent_message_id
    assert_equal "customer_to_admin", reply.message_type
    assert_equal "sent", reply.status
    assert_equal @user, reply.sender
  end
  
  test "admin messages are marked as read when user views them" do
    sign_in @user
    
    # Create unread admin messages
    message1 = create_admin_message(@application, @admin, @agent, "Message 1")
    message2 = create_admin_message(@application, @admin, @agent, "Message 2")
    
    # Verify they start as "sent" (unread)
    assert_equal "sent", message1.reload.status
    assert_equal "sent", message2.reload.status
    
    # User visits messages page
    get messages_application_path(@application)
    assert_response :success
    
    # Messages should now be marked as "read"
    assert_equal "read", message1.reload.status
    assert_equal "read", message2.reload.status
    assert_not_nil message1.read_at
    assert_not_nil message2.read_at
  end
  
  test "user sees AI agent information correctly" do
    sign_in @user
    
    # Create message from AI agent
    message = create_admin_message(@application, @admin, @agent, "Hello from Motoko!")
    
    get messages_application_path(@application)
    assert_response :success
    
    # Should show AI agent name and badge
    assert_select ".sender-name strong", text: "Motoko AI Assistant"
    assert_select ".ai-assistant-badge", text: "AI Assistant"
    assert_select ".sender-role", text: "Application Processing Specialist"
    
    # Should show agent avatar (or fallback)
    assert_select ".ai-agent-avatar, .default-avatar", count: 1
  end
  
  test "message content is properly formatted with markup" do
    sign_in @user
    
    content = "Hello **John**!\n\n*Here's what's next:*\n\n- Review your application\n- Submit additional documents\n- Wait for approval"
    message = create_admin_message(@application, @admin, @agent, "Next Steps", content)
    
    get messages_application_path(@application)
    assert_response :success
    
    # Should render markup as HTML
    assert_select ".message-content strong", text: "John"
    assert_select ".message-content em", text: "Here's what's next:"
    assert_select ".message-content ul li", count: 3
    assert_select ".message-content li", text: "Review your application"
  end
  
  test "template variables are processed in message content" do
    sign_in @user
    
    content = "Hello {{user.first_name}}! Your application for {{application.address}} is being reviewed."
    message = create_admin_message(@application, @admin, @agent, "Update", content)
    
    get messages_application_path(@application)
    assert_response :success
    
    # Should show processed variables
    assert_select ".message-content", text: /Hello #{@user.first_name}!/
    assert_select ".message-content", text: /#{@application.address}/
  end
  
  test "user can navigate back to dashboard from messages" do
    sign_in @user
    
    get messages_application_path(@application)
    assert_response :success
    
    # Should have back to dashboard link
    assert_select "a[href='#{dashboard_path}']", text: /Back to Dashboard/
  end
  
  test "expired secure token redirects to login" do
    # Create expired token
    payload = {
      application_id: @application.id,
      user_id: @user.id,
      expires_at: 1.hour.ago.to_i # Expired
    }
    token = SecureTokenEncryptor.encrypt_and_sign(payload)
    
    get messages_application_path(@application, token: token)
    
    assert_redirected_to new_user_session_path
    assert_equal "This link has expired. Please log in to access your messages.", flash[:alert]
  end
  
  test "invalid secure token redirects to login" do
    # Use invalid token
    get messages_application_path(@application, token: "invalid_token")
    
    assert_redirected_to new_user_session_path
    assert_equal "Invalid access link. Please log in to continue.", flash[:alert]
  end
  
  test "user cannot access other users' messages" do
    other_user = create_user("other@test.com")
    other_application = create_application_for_user(other_user)
    create_admin_message(other_application, @admin, @agent, "Not for you")
    
    sign_in @user
    
    # Try to access other user's messages
    assert_raises(ActiveRecord::RecordNotFound) do
      get messages_application_path(other_application)
    end
  end
  
  test "messages display in correct chronological order (newest first)" do
    sign_in @user
    
    # Create messages with specific timestamps  
    old_message = create_admin_message(@application, @admin, @agent, "Old message")
    old_message.update!(created_at: 3.hours.ago)
    
    middle_message = create_admin_message(@application, @admin, @agent, "Middle message")
    middle_message.update!(created_at: 2.hours.ago)
    
    new_message = create_admin_message(@application, @admin, @agent, "New message")
    new_message.update!(created_at: 1.hour.ago)
    
    get messages_application_path(@application)
    assert_response :success
    
    # Check order (newest first)
    message_subjects = css_select(".message-subject h3").map(&:text)
    assert_equal ["New message", "Middle message", "Old message"], message_subjects
  end
  
  test "reply form pre-fills subject with Re: prefix" do
    sign_in @user
    
    message = create_admin_message(@application, @admin, @agent, "Original Subject")
    
    get messages_application_path(@application)
    assert_response :success
    
    # Reply form should have pre-filled subject
    assert_select "input[name='application_message[subject]'][value='Re: Original Subject']"
    assert_select "input[name='application_message[parent_message_id]'][value='#{message.id}']", visible: false
  end
  
  test "empty state shows when no messages exist" do
    sign_in @user
    
    get messages_application_path(@application)
    assert_response :success
    
    # Should show empty state
    assert_select ".empty-state", count: 1
    assert_select ".empty-state h3", text: "No messages yet"
    assert_select ".empty-state p", text: /When Futureproof sends you messages/
  end
  
  private
  
  def create_user(email = nil)
    User.create!(
      first_name: "John",
      last_name: "Doe",
      email: email || "user-#{SecureRandom.hex(4)}@test.com",
      password: "password123", 
      password_confirmation: "password123",
      terms_accepted: true
    )
  end
  
  def create_admin_user
    User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123", 
      admin: true,
      terms_accepted: true
    )
  end
  
  def create_application_for_user(user)
    user.applications.create!(
      status: "submitted",
      home_value: 800000,
      address: "123 Test Street, Test City",
      borrower_age: 65,
      ownership_status: "individual"
    )
  end
  
  def create_ai_agent(name = "TestAgent", agent_type = "applications", avatar = "Motoko.png")
    AiAgent.create!(
      name: name,
      agent_type: agent_type,
      avatar_filename: avatar,
      is_active: true,
      greeting_style: "friendly"
    )
  end
  
  def create_admin_message(application, admin, agent, subject, content = "Test message content")
    application.application_messages.create!(
      sender: admin,
      ai_agent: agent,
      subject: subject,
      content: content,
      message_type: "admin_to_customer",
      status: "sent",
      sent_at: Time.current
    )
  end
end