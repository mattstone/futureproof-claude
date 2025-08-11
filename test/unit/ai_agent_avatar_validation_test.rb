require "test_helper"

class AiAgentAvatarValidationTest < ActiveSupport::TestCase
  def setup
    @application = create_test_application
    @admin_user = create_admin_user
  end
  
  test "ai_agent avatar_path returns correct path for existing files" do
    # Test with actual files that exist
    motoko = AiAgent.create!(name: "Motoko", agent_type: "applications", avatar_filename: "Motoko.png", is_active: true)
    rie = AiAgent.create!(name: "Rie", agent_type: "backoffice", avatar_filename: "Rie.png", is_active: true)
    yumi = AiAgent.create!(name: "Yumi", agent_type: "investment", avatar_filename: "Yumi.png", is_active: true)
    
    assert_equal "ai-agents/Motoko.png", motoko.avatar_path
    assert_equal "ai-agents/Rie.png", rie.avatar_path
    assert_equal "ai-agents/Yumi.png", yumi.avatar_path
  end
  
  test "ai_agent asset_avatar_path handles missing files gracefully" do
    agent = AiAgent.create!(name: "TestAgent", agent_type: "applications", avatar_filename: "nonexistent.png", is_active: true)
    
    # Should return a path even if file doesn't exist
    assert_includes agent.asset_avatar_path, "nonexistent.png"
  end
  
  test "application_message sender_avatar_path works with valid ai_agent" do
    agent = AiAgent.create!(name: "TestAgent", agent_type: "applications", avatar_filename: "Motoko.png", is_active: true)
    
    message = @application.application_messages.create!(
      sender: @admin_user,
      ai_agent: agent,
      subject: "Test message",
      content: "Test content",
      message_type: "admin_to_customer",
      status: "sent"
    )
    
    assert_equal "ai-agents/Motoko.png", message.sender_avatar_path
    assert message.from_ai_agent?
  end
  
  test "application_message handles missing ai_agent gracefully" do
    message = @application.application_messages.create!(
      sender: @admin_user,
      subject: "Test message",
      content: "Test content", 
      message_type: "admin_to_customer",
      status: "sent"
    )
    
    assert_nil message.sender_avatar_path
    assert_not message.from_ai_agent?
  end
  
  test "message_threads scope includes messages with ai_agents" do
    agent = AiAgent.create!(name: "TestAgent", agent_type: "applications", avatar_filename: "Motoko.png", is_active: true)
    
    # Create messages with and without ai_agent
    message_with_agent = @application.application_messages.create!(
      sender: @admin_user,
      ai_agent: agent,
      subject: "With agent",
      content: "Test content",
      message_type: "admin_to_customer",
      status: "sent"
    )
    
    message_without_agent = @application.application_messages.create!(
      sender: @admin_user,
      subject: "Without agent", 
      content: "Test content",
      message_type: "admin_to_customer",
      status: "sent"
    )
    
    threads = @application.message_threads
    assert_equal 2, threads.count
    assert_includes threads, message_with_agent
    assert_includes threads, message_without_agent
  end
  
  test "only active ai_agents are suggested for applications" do
    active_agent = AiAgent.create!(name: "ActiveAgent", agent_type: "applications", avatar_filename: "Motoko.png", is_active: true)
    inactive_agent = AiAgent.create!(name: "InactiveAgent", agent_type: "applications", avatar_filename: "Rie.png", is_active: false)
    
    suggested = AiAgent.suggest_for_application(@application)
    
    # Should suggest active agent, not inactive one
    assert_equal active_agent, suggested
  end
  
  test "message history includes ai_agent information" do
    agent = AiAgent.create!(name: "TestAgent", agent_type: "applications", avatar_filename: "Motoko.png", is_active: true)
    
    message = @application.application_messages.create!(
      sender: @admin_user,
      ai_agent: agent,
      subject: "Test message",
      content: "Test content",
      message_type: "admin_to_customer", 
      status: "sent"
    )
    
    # Test that message includes ai_agent when loaded with includes
    threads = @application.message_threads
    loaded_message = threads.first
    
    assert_equal agent.id, loaded_message.ai_agent.id
    assert_equal "TestAgent AI Assistant", loaded_message.sender_name
    assert_equal "Application Processing Specialist", loaded_message.sender_role
  end
  
  private
  
  def create_test_application
    user = create_customer_user
    user.applications.create!(
      status: "submitted",
      home_value: 500000,
      address: "123 Test Street",
      borrower_age: 65,
      ownership_status: "individual"
    )
  end
  
  def create_admin_user
    User.create!(
      first_name: "Admin",
      last_name: "Test",
      email: "admin-unit-test-#{SecureRandom.hex(4)}@test.com", 
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true
    )
  end
  
  def create_customer_user
    User.create!(
      first_name: "Customer",
      last_name: "Test",
      email: "customer-unit-test-#{SecureRandom.hex(4)}@test.com",
      password: "password123", 
      password_confirmation: "password123",
      terms_accepted: true
    )
  end
end