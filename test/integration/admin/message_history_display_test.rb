require "test_helper"

class Admin::MessageHistoryDisplayTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = create_admin_user
    @customer = create_customer_user
    @application = create_application_for_user(@customer)
    @agent = create_ai_agent
    
    sign_in @admin_user
  end
  
  test "message history displays sent messages" do
    # Create a few messages
    message1 = create_message(@application, @admin_user, @agent, "First message", "sent")
    message2 = create_message(@application, @admin_user, @agent, "Second message", "sent")
    message3 = create_message(@application, @admin_user, @agent, "Third message", "draft")
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should show sent messages
    assert_select ".message-threads" do
      assert_select ".message-thread", count: 3
      assert_select ".message-thread", text: /First message/
      assert_select ".message-thread", text: /Second message/
      assert_select ".message-thread", text: /Third message/
    end
    
    # Check that messages show correct agent info
    assert_select ".sender-name", text: /#{@agent.display_name}/
  end
  
  test "message history handles missing avatar gracefully" do
    # Create agent with non-existent avatar
    bad_agent = AiAgent.create!(
      name: "BadAgent", 
      agent_type: "applications",
      avatar_filename: "nonexistent.png",
      is_active: true
    )
    
    message = create_message(@application, @admin_user, bad_agent, "Test message", "sent")
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should still display the message despite missing avatar
    assert_select ".message-threads" do
      assert_select ".message-thread", count: 1
      assert_select ".message-thread", text: /Test message/
    end
    
    # Should show fallback avatar
    assert_select ".sender-avatar .fas.fa-robot"
  end
  
  test "message history shows empty state when no messages" do
    get admin_application_path(@application)
    
    assert_response :success
    assert_select ".empty-state", text: /No messages yet/
  end
  
  test "message history displays messages in reverse chronological order (newest first)" do
    # Create messages with specific timestamps
    message1 = create_message(@application, @admin_user, @agent, "Oldest message", "sent")
    message1.update!(created_at: 3.hours.ago)
    
    message2 = create_message(@application, @admin_user, @agent, "Middle message", "sent")  
    message2.update!(created_at: 2.hours.ago)
    
    message3 = create_message(@application, @admin_user, @agent, "Newest message", "sent")
    message3.update!(created_at: 1.hour.ago)
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Get all message subjects in order they appear (should be newest first)
    page = Nokogiri::HTML(response.body)
    message_subjects = page.css('.message-subject strong').map(&:text)
    
    assert_equal ["Newest message", "Middle message", "Oldest message"], message_subjects
  end
  
  test "message history includes replies correctly" do
    # Create parent message
    parent = create_message(@application, @admin_user, @agent, "Parent message", "sent")
    
    # Create reply
    reply = create_message(@application, @customer, nil, "Customer reply", "sent")
    reply.update!(parent_message_id: parent.id)
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should show parent message (replies are loaded via includes)
    assert_select ".message-thread", text: /Parent message/
    
    # Check that reply is loaded (may be shown in replies section)
    assert_select ".message-replies", text: /Customer reply/ if reply.present?
  end
  
  test "message history displays different agent avatars correctly" do
    # Create messages from different agents
    motoko = AiAgent.find_by(name: "Motoko") || create_ai_agent("Motoko", "applications", "Motoko.png")
    rie = AiAgent.find_by(name: "Rie") || create_ai_agent("Rie", "backoffice", "Rie.png")
    
    message1 = create_message(@application, @admin_user, motoko, "From Motoko", "sent")
    message2 = create_message(@application, @admin_user, rie, "From Rie", "sent")
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should display both messages
    assert_select ".message-threads" do
      assert_select ".message-thread", count: 2
      assert_select ".message-thread", text: /From Motoko/
      assert_select ".message-thread", text: /From Rie/
    end
  end
  
  test "message history persists after sending new message" do
    # Create existing message
    existing = create_message(@application, @admin_user, @agent, "Existing message", "sent")
    
    # Send new message via POST
    post create_message_admin_application_path(@application), params: {
      application_message: {
        subject: "New test message",
        content: "This is a new message",
        ai_agent_id: @agent.id
      },
      send_now: "Send Message"
    }
    
    follow_redirect!
    
    assert_response :success
    
    # Should show both old and new messages
    assert_select ".message-threads" do
      assert_select ".message-thread", count: 2
      assert_select ".message-thread", text: /Existing message/
      assert_select ".message-thread", text: /New test message/
    end
  end
  
  private
  
  def create_admin_user
    User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-test-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true
    )
  end
  
  def create_customer_user
    User.create!(
      first_name: "Customer",
      last_name: "User", 
      email: "customer-test-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
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
  
  def create_message(application, sender, ai_agent, subject, status)
    application.application_messages.create!(
      sender: sender,
      ai_agent: ai_agent,
      subject: subject,
      content: "Test message content for #{subject}",
      message_type: sender.admin? ? "admin_to_customer" : "customer_to_admin",
      status: status,
      sent_at: status == "sent" ? Time.current : nil
    )
  end
end