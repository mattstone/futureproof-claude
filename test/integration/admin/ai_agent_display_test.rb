require 'test_helper'

class Admin::AiAgentDisplayTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    @application = applications(:submitted_application)
    
    # Clean up existing AI agents to avoid interference
    AiAgent.destroy_all
    
    # Create AI agents for testing
    @ai_agent = AiAgent.create!(
      name: 'TestBot',
      agent_type: 'applications',
      avatar_filename: 'Motoko.png',
      greeting_style: 'friendly',
      is_active: true,
      specialties: 'Application Processing'
    )
    
    @ai_agent_2 = AiAgent.create!(
      name: 'SecondBot',
      agent_type: 'backoffice',
      avatar_filename: 'Rie.png',
      greeting_style: 'professional',
      is_active: true,
      specialties: 'Back Office Operations'
    )
    
    # Log in as admin
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
  end

  test "edit page displays AI agent dropdown with options" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that AI agent dropdown is present
    assert_select 'select#application_message_ai_agent_id'
    
    # Check that both agents are listed as options
    assert_select 'select#application_message_ai_agent_id option[value=""]', text: 'Select AI Agent...', count: 1
    assert_select 'select#application_message_ai_agent_id option[value="' + @ai_agent.id.to_s + '"]', 
                  text: @ai_agent.display_name, count: 1
    assert_select 'select#application_message_ai_agent_id option[value="' + @ai_agent_2.id.to_s + '"]', 
                  text: @ai_agent_2.display_name, count: 1
  end

  test "edit page includes agent preview div with correct structure" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that agent preview div exists and is visible when suggested agent exists
    assert_select 'div#agent-preview.agent-preview[style*="display: block"]'
    
    # Check that preview structure is correct
    assert_select 'div#agent-preview .agent-info'
    assert_select 'div#agent-preview .agent-info .agent-details'
    assert_select 'div#agent-preview .agent-info .agent-details .agent-name'
    assert_select 'div#agent-preview .agent-info .agent-details .agent-role'
    assert_select 'div#agent-preview .agent-info .agent-details .agent-specialties'
  end

  test "edit page includes JavaScript for agent data" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that window.agentData is populated
    assert_match /window\.agentData\s*=/, response.body
    
    # Check that agent data includes our test agents
    assert_match /"name":"TestBot"/, response.body
    assert_match /"name":"SecondBot"/, response.body
    assert_match /"agent_type":"applications"/, response.body
    assert_match /"agent_type":"backoffice"/, response.body
  end

  test "edit page includes updateAgentPreview function" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that updateAgentPreview function is defined
    assert_match /function updateAgentPreview\(select\)/, response.body
    
    # Check that initialization code exists
    assert_match /document\.addEventListener\('DOMContentLoaded'/, response.body
    assert_match /updateAgentPreview\(selectElement\)/, response.body
  end

  test "edit page includes backup initialization for page load" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that backup window load event exists
    assert_match /window\.addEventListener\('load'/, response.body
    assert_match /preview\.style\.display === 'none'/, response.body
  end

  test "JavaScript includes proper agent data structure" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify that agent data includes the required methods
    assert_match /"display_name":"TestBot AI Assistant"/, response.body
    assert_match /"role_description":"Application Processing Specialist"/, response.body
    assert_match /"asset_avatar_path":.*Motoko\.png/, response.body
    
    # Verify that sensitive fields are excluded
    assert_no_match /"created_at":/, response.body
    assert_no_match /"updated_at":/, response.body
  end

  test "suggested agent can be pre-selected in dropdown" do
    # Test that when an application has a "submitted" status, 
    # an applications-type agent should be suggested
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that our applications-type agent (TestBot) should be available
    assert_select "select#application_message_ai_agent_id option[value='#{@ai_agent.id}']", 
                  text: @ai_agent.display_name, count: 1
    
    # The suggest_for_application logic should return @ai_agent for 'submitted' status
    # since it defaults to for_application_context which should return our applications-type agent
    suggested = AiAgent.suggest_for_application(@application)
    assert_not_nil suggested, "A suggested agent should be returned"
    assert_equal @ai_agent.id, suggested.id, "Our applications-type agent should be suggested"
  end

  test "onchange handler is present on agent selection dropdown" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that onchange handler calls updateAgentPreview
    assert_select 'select#application_message_ai_agent_id[onchange="updateAgentPreview(this)"]'
  end

  test "agent preview updates correctly via JavaScript" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that JavaScript logic handles agent selection correctly
    assert_match /const agentId = parseInt\(select\.value\)/, response.body
    assert_match /const agent = window\.agentData\.find/, response.body
    assert_match /avatarImg\.src = agent\.asset_avatar_path/, response.body
    assert_match /if \(nameEl\) nameEl\.textContent = agent\.display_name/, response.body
    assert_match /if \(roleEl\) roleEl\.textContent = agent\.role_description/, response.body
  end

  test "agent preview includes error handling for broken images" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that image error handling exists
    assert_match /avatarImg\.onerror = function\(\)/, response.body
    assert_match /this\.style\.display = 'none'/, response.body
    assert_match /agent-avatar-fallback/, response.body
    assert_match /agent\.name\.charAt\(0\)\.toUpperCase\(\)/, response.body
  end

  test "page includes multiple initialization timeouts for reliable loading" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that multiple setTimeout calls are used for robust initialization
    assert_match /setTimeout\(initializeAgentPreview, 10\)/, response.body
    assert_match /setTimeout\(initializeAgentPreview, 50\)/, response.body 
    assert_match /setTimeout\(initializeAgentPreview, 100\)/, response.body
  end
  
  test "JavaScript includes initialization function and multiple event listeners" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that the initializeAgentPreview function exists
    assert_match /function initializeAgentPreview\(\) {/, response.body
    
    # Check that multiple initialization attempts are present
    assert_match /setTimeout\(initializeAgentPreview, 10\)/, response.body
    assert_match /setTimeout\(initializeAgentPreview, 50\)/, response.body
    assert_match /setTimeout\(initializeAgentPreview, 100\)/, response.body
    
    # Check for Turbo navigation handling
    assert_match /document\.addEventListener\('turbo:load', initializeAgentPreview\)/, response.body
  end
  
  test "JavaScript handles missing elements gracefully in updateAgentPreview" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that function handles missing preview elements
    assert_match /if \(!preview\) {/, response.body
    assert_match /return;/, response.body
    
    # Check individual element validation
    assert_match /if \(avatarImg\)/, response.body
    assert_match /if \(nameEl\)/, response.body
    assert_match /if \(roleEl\)/, response.body
    assert_match /if \(specialtiesEl\)/, response.body
  end

  test "agent display name includes AI Assistant suffix" do
    assert_equal 'TestBot AI Assistant', @ai_agent.display_name
    assert_equal 'SecondBot AI Assistant', @ai_agent_2.display_name
  end

  test "agent role descriptions are correct for different types" do
    assert_equal 'Application Processing Specialist', @ai_agent.role_description
    assert_equal 'Back Office Operations Assistant', @ai_agent_2.role_description
  end

  test "agent asset avatar paths are generated correctly" do
    expected_path = ActionController::Base.helpers.asset_path('ai-agents/Motoko.png')
    assert_equal expected_path, @ai_agent.asset_avatar_path
    
    expected_path_2 = ActionController::Base.helpers.asset_path('ai-agents/Rie.png')
    assert_equal expected_path_2, @ai_agent_2.asset_avatar_path
  end

  test "agent preview displays correctly when there is a suggested agent" do
    # Ensure our application-type agent will be suggested for submitted status
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify that our applications-type agent is suggested
    suggested_agent = AiAgent.suggest_for_application(@application)
    assert_equal @ai_agent.id, suggested_agent.id
    
    # Check that the dropdown has the suggested agent selected
    # The options_from_collection_for_select should select @suggested_agent&.id
    assert_select "select#application_message_ai_agent_id" do
      assert_select "option[selected][value='#{@ai_agent.id}']", text: @ai_agent.display_name
    end
    
    # Verify that agent data includes our suggested agent
    assert_match /"id":#{@ai_agent.id}/, response.body
    assert_match /"display_name":"#{@ai_agent.display_name}"/, response.body
    assert_match /"role_description":"#{@ai_agent.role_description}"/, response.body
    
    # Verify that the JavaScript initialization should work
    # (The actual preview display test would require JavaScript execution)
    assert_match /if \(selectElement && selectElement\.value && selectElement\.value !== ''\) {/, response.body
    assert_match /updateAgentPreview\(selectElement\);/, response.body
  end
  
  test "agent preview content is populated on server side when suggested agent exists" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify that the preview is visible (not hidden)
    assert_select 'div#agent-preview[style*="display: block"]'
    
    # Verify that the agent details are populated with actual content
    assert_select 'div#agent-preview .agent-name', text: @ai_agent.display_name
    assert_select 'div#agent-preview .agent-role', text: @ai_agent.role_description  
    assert_select 'div#agent-preview .agent-specialties', text: /Specialties: #{@ai_agent.specialties || 'General assistance'}/
    
    # Verify avatar is present (either img tag or fallback)
    avatar_present = false
    begin
      assert_select 'div#agent-preview img.agent-avatar'
      avatar_present = true
    rescue Minitest::Assertion
      # If image fails, check for fallback div
      assert_select 'div#agent-preview .agent-avatar-fallback', text: @ai_agent.name.first.upcase
      avatar_present = true
    end
    
    assert avatar_present, "Either avatar image or fallback should be present"
  end

  test "page loads successfully even when no AI agents exist" do
    # Remove all AI agents
    AiAgent.destroy_all
    
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should still have the dropdown but with no options except prompt
    assert_select 'select#application_message_ai_agent_id'
    assert_select 'select#application_message_ai_agent_id option', count: 1 # Only the prompt option
    assert_match /window\.agentData\s*=\s*\[\]/, response.body # Empty array
  end

  test "JavaScript handles empty agent selection gracefully" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Check that function handles empty/null agent ID  
    assert_match /if \(!agentId \|\| isNaN\(agentId\)\) {/, response.body
    assert_match /if \(preview\) preview\.style\.display = 'none'/, response.body
    assert_match /if \(!agent\) {/, response.body
  end
end