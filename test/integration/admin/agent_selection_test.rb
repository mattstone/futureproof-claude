require 'test_helper'

class Admin::AgentSelectionTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :ai_agents

  def setup
    @admin = users(:admin_user)
    @application = applications(:submitted_application)
    
    # Use the existing customer success manager agent from fixtures
    @suggested_agent = ai_agents(:customer_success_manager)
    
    # Log in as admin
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
  end

  test "should have suggested agent selected initially in messaging form" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have the suggested agent selected in the dropdown
    assert_select "select#application_message_ai_agent_id option[selected][value='#{@suggested_agent.id}']"
    
    # Should show agent preview
    assert_select "#agent-preview[style*='display: block']"
    assert_select "#agent-preview .agent-name", text: @suggested_agent.display_name
  end

  test "should keep suggested agent selected after sending message via Turbo Stream" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Send a message via Turbo Stream
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @suggested_agent.id,
        subject: "Test Subject",
        content: "Test content"
      },
      send_now: "Send Message Now"
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_match /turbo-stream/, response.content_type
    
    # Verify SOME agent is still selected in the refreshed form (the suggested one)
    assert_match /selected="selected"/, response.body
    
    # Should show agent preview with agent's info
    assert_match /display: block/, response.body
    assert_match /#{@suggested_agent.display_name}/, response.body
  end

  test "should handle case when no agents exist" do
    # Clean up messages first to avoid foreign key constraints
    ApplicationMessage.delete_all
    ContractMessage.delete_all
    AiAgent.destroy_all
    
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should still show the form but with empty dropdown
    assert_select "select#application_message_ai_agent_id"
    assert_select "#agent-preview[style*='display: none']"
  end

  test "should maintain agent selection after save as draft via Turbo Stream" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Save as draft instead of sending
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @suggested_agent.id,
        subject: "Draft Subject",
        content: "Draft content"
      },
      save_draft: "Save as Draft"
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_match /turbo-stream/, response.content_type
    
    # Should still have agent selected
    assert_match /selected="selected"/, response.body
    assert_match /display: block/, response.body
  end

  test "should show agent preview immediately when agent is pre-selected" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have agent preview visible because suggested agent is selected
    assert_select "#agent-preview[style*='display: block']"
    assert_select "#agent-preview .agent-name", text: @suggested_agent.display_name
    assert_select "#agent-preview .agent-role", text: @suggested_agent.role_description
    assert_select "#agent-preview .agent-specialties", text: /#{@suggested_agent.specialties}/
    
    # Should have avatar or fallback
    assert_select "#agent-preview img.agent-avatar, #agent-preview .agent-avatar-fallback"
  end
end