require 'test_helper'

class EmailLinkEndToEndTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications
  
  def setup
    @user = users(:john)
    @admin = users(:admin_user)
    @application = applications(:submitted_application)
    @application.update!(user: @user)
  end

  test "complete email link workflow from admin sending message to customer viewing it" do
    # Step 1: Admin sends a message (simulating the admin workflow)
    admin_sign_in
    
    # Create an AI agent for the test
    ai_agent = AiAgent.create!(
      name: 'TestBot',
      agent_type: 'applications',
      avatar_filename: 'Motoko.png',
      greeting_style: 'friendly',
      is_active: true,
      specialties: 'Application Processing'
    )
    
    # Admin sends a message
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: ai_agent.id,
        subject: "Important Update About Your Application",
        content: "We have an important update regarding your mortgage application."
      },
      send_now: "Send Message Now"
    }
    
    assert_response :redirect
    
    # Verify message was created
    message = ApplicationMessage.last
    assert_not_nil message
    assert_equal "Important Update About Your Application", message.subject
    assert_equal @application, message.application
    
    # Step 2: Simulate receiving the email and clicking the link
    sign_out @admin
    
    # Generate the secure token (simulating what the mailer would generate)
    token = generate_secure_token(@application, @user, message)
    
    # Customer clicks the email link (not logged in)
    get messages_application_path(@application, token: token, message_id: message.id)
    
    # Should redirect to login
    assert_redirected_to new_user_session_path
    assert_equal 'Please log in to access your message.', flash[:notice]
    
    follow_redirect!
    assert_response :success
    assert_select 'form' # Login form should be present
    
    # Step 3: Customer logs in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    
    # Should redirect to the specific message
    assert_redirected_to messages_application_path(@application, message_id: message.id)
    
    follow_redirect!
    assert_response :success
    
    # Step 4: Verify the message is displayed and highlighted
    assert_select ".message-thread.highlighted#message-#{message.id}"
    assert_select "#message-#{message.id} .message-subject", text: message.subject
    assert_select "#message-#{message.id} .message-content", text: /important update regarding your mortgage application/i
    
    # Verify the page shows all the expected elements
    assert_select "h1", text: "Messages"
    assert_select ".message-threads-section h2", text: "Messages from Futureproof"
    assert_select ".reply-form-section", count: 1  # Should have reply form
    
    # Step 5: Customer can reply to the message
    post reply_to_message_application_path(@application), params: {
      application_message: {
        parent_message_id: message.id,
        subject: "Re: Important Update About Your Application",
        content: "Thank you for the update. I have some questions about this."
      }
    }
    
    assert_redirected_to messages_application_path(@application)
    
    follow_redirect!
    assert_response :success
    
    # Verify the reply was created and is displayed
    reply = ApplicationMessage.where(parent_message: message).last
    assert_not_nil reply
    assert_equal @user, reply.sender
    assert_equal "Re: Important Update About Your Application", reply.subject
    
    # Should see the reply in the interface
    assert_select ".message-reply .reply-content", text: /Thank you for the update/
  end

  private

  def admin_sign_in
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
  end

  def sign_out(user)
    delete destroy_user_session_path
  end

  def generate_secure_token(application, user, message)
    payload = {
      application_id: application.id,
      user_id: user.id,
      expires_at: 24.hours.from_now.to_i
    }
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end