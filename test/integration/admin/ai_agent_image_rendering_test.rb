require 'test_helper'

class Admin::AiAgentImageRenderingTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  
  setup do
    # Create a mock mailer to prevent actual email sending during tests
    mock_mail = Object.new
    def mock_mail.deliver_now; end
    ApplicationMailer.define_singleton_method(:message_notification) { |_| mock_mail }
    
    @admin = User.create!(
      email: 'admin@example.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      terms_accepted: true,
      terms_version: 1
    )
    
    @customer = User.create!(
      email: 'customer@example.com', 
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      admin: false,
      terms_accepted: true,
      terms_version: 1
    )
    
    @application = Application.create!(
      user: @customer,
      address: '123 Main Street, Anytown, AT 12345',
      home_value: 750000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
    )
    
    @ai_agent = AiAgent.create!(
      name: 'motoko',
      agent_type: 'applications',
      description: 'Handles customer inquiries and updates',
      specialties: 'Customer service, application status updates',
      avatar_filename: 'Motoko.png',
      is_active: true
    )
    
    # Sign in as admin
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: 'password123'
      }
    }
  end
  
  test "should render agent data with proper asset paths in JavaScript" do
    get admin_application_path(@application)
    
    assert_response :success
    
    # Check that the JavaScript contains the agent data
    assert_select 'script', text: /window\.agentData/
    
    # Verify the agent selection dropdown exists
    assert_select 'select[name="application_message[ai_agent_id]"]'
    assert_select 'option[value=?]', @ai_agent.id.to_s
    
    # Verify the agent preview container exists
    assert_select '#agent-preview.agent-preview'
    assert_select '.agent-avatar'
    assert_select '.agent-name'
    assert_select '.agent-role'
    assert_select '.agent-specialties'
    
    # Check that the JavaScript includes the updateAgentPreview function
    assert_select 'script', text: /updateAgentPreview/
    
    # Verify agent data structure includes asset path method
    assert_match /asset_avatar_path/, response.body
  end
  
  test "should display agent preview with correct data structure in show view" do
    get admin_application_path(@application)
    
    assert_response :success
    
    # Extract the agent data from the JavaScript
    agent_data_match = response.body.match(/window\.agentData = (\[.*?\]);/m)
    assert_not_nil agent_data_match, "Agent data should be present in JavaScript"
    
    # Parse the JSON (basic structure check)
    agent_data_json = agent_data_match[1]
    assert_match /"display_name":"#{@ai_agent.display_name}"/, agent_data_json
    assert_match /"role_description":"#{@ai_agent.role_description}"/, agent_data_json
    assert_match /"asset_avatar_path":".*Motoko.*\.png"/, agent_data_json
    assert_match /"avatar_filename":"Motoko\.png"/, agent_data_json
  end
  
  test "should display agent preview with correct data structure in edit view" do
    get edit_admin_application_path(@application)
    
    assert_response :success
    
    # Verify the same functionality exists in edit view
    assert_select 'script', text: /window\.agentData/
    assert_select '#agent-preview.agent-preview'
    assert_select 'select[name="application_message[ai_agent_id]"]'
    
    # Extract the agent data from the JavaScript
    agent_data_match = response.body.match(/window\.agentData = (\[.*?\]);/m)
    assert_not_nil agent_data_match, "Agent data should be present in JavaScript"
    
    # Parse the JSON (basic structure check)
    agent_data_json = agent_data_match[1]
    assert_match /"asset_avatar_path":".*Motoko.*\.png"/, agent_data_json
  end
  
  test "should handle multiple agents with different avatars" do
    # Create another agent with a different avatar
    @second_agent = AiAgent.create!(
      name: 'rie',
      agent_type: 'backoffice',
      description: 'Back office operations specialist',
      specialties: 'Operations, administrative tasks',
      avatar_filename: 'Rie.png',
      is_active: true
    )
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should have both agents in the dropdown
    assert_select 'option[value=?]', @ai_agent.id.to_s
    assert_select 'option[value=?]', @second_agent.id.to_s
    
    # Check both agents are in the JavaScript data
    assert_match /"name":"motoko"/, response.body
    assert_match /"name":"rie"/, response.body
    assert_match /"avatar_filename":"Motoko\.png"/, response.body
    assert_match /"avatar_filename":"Rie\.png"/, response.body
  end
  
  test "should provide fallback for agents with missing avatar files" do
    # Create an agent with a non-existent avatar file
    @missing_avatar_agent = AiAgent.create!(
      name: 'test',
      agent_type: 'applications',
      description: 'Test agent with missing avatar',
      specialties: 'Testing',
      avatar_filename: 'nonexistent.png',
      is_active: true
    )
    
    get admin_application_path(@application)
    
    assert_response :success
    
    # Should still render the page without errors
    assert_select 'select[name="application_message[ai_agent_id]"]'
    assert_select 'option[value=?]', @missing_avatar_agent.id.to_s
    
    # JavaScript should include error handling
    assert_select 'script', text: /onerror/
    assert_select 'script', text: /agent-avatar-fallback/
  end
end