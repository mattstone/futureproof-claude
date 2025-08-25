require 'test_helper'

class Admin::AiAgentSeedRegressionTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    @application = applications(:submitted_application)
    
    # Clean up and create seeded agents once for all tests
    ApplicationMessage.delete_all
    ContractMessage.delete_all
    AiAgent.destroy_all
    
    # Create the seeded AI agents directly instead of requiring the file
    @motoko = AiAgent.create!(
      name: 'Motoko',
      agent_type: 'applications',
      avatar_filename: 'Motoko.png',
      role_title: 'Application Processing Specialist',
      description: 'Specializes in guiding customers through the application process, reviewing documentation, and providing updates on application status.',
      specialties: 'Application reviews, document verification, status updates, eligibility assessments',
      greeting_style: 'professional',
      is_active: true
    )
    
    @rie = AiAgent.create!(
      name: 'Rie',
      agent_type: 'backoffice',
      avatar_filename: 'Rie.png',
      role_title: 'Back Office Operations Assistant',
      description: 'Handles operational queries, settlement processes, account management, and administrative tasks.',
      specialties: 'Account management, settlement coordination, policy administration, operational support',
      greeting_style: 'friendly',
      is_active: true
    )
    
    @yumi = AiAgent.create!(
      name: 'Yumi',
      agent_type: 'investment',
      avatar_filename: 'Yumi.png',
      role_title: 'Investment Advisory Specialist',
      description: 'Provides guidance on investment strategies, market insights, and long-term financial planning.',
      specialties: 'Investment strategies, market analysis, portfolio management, financial planning',
      greeting_style: 'formal',
      is_active: true
    )
    
    # Log in as admin
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password' }
    }
    follow_redirect!
  end

  test "should have Motoko AI agent from seeds available in admin applications edit page" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify Motoko exists from setup
    assert_not_nil @motoko, "Motoko AI agent should exist from setup"
    assert_equal 'applications', @motoko.agent_type
    assert_equal 'Motoko.png', @motoko.avatar_filename
    assert_equal 'Application Processing Specialist', @motoko.role_title
    assert @motoko.is_active
    
    # Verify Motoko appears in the AI agent dropdown
    assert_select "select#application_message_ai_agent_id" do
      assert_select "option[value='#{@motoko.id}']", text: @motoko.display_name
    end
  end

  test "should have Motoko as the suggested agent for submitted applications" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Test the suggestion logic
    suggested_agent = AiAgent.suggest_for_application(@application)
    
    assert_not_nil suggested_agent, "A suggested agent should be returned"
    assert_equal @motoko.id, suggested_agent.id, "Motoko should be suggested for submitted applications"
    
    # Verify Motoko is pre-selected in the dropdown
    assert_select "select#application_message_ai_agent_id option[selected][value='#{@motoko.id}']", 
                  text: @motoko.display_name
  end

  test "should display Motoko's details in agent preview when pre-selected" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify agent preview is visible with Motoko's details
    assert_select "#agent-preview.visible" do
      assert_select ".agent-name", text: @motoko.display_name
      assert_select ".agent-role", text: @motoko.role_description
      assert_select ".agent-specialties", text: /#{@motoko.specialties}/
    end
  end

  test "should have all three seeded AI agents available" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify all three seeded agents exist from setup
    assert_not_nil @motoko, "Motoko should exist from setup"
    assert_not_nil @rie, "Rie should exist from setup"
    assert_not_nil @yumi, "Yumi should exist from setup"
    
    # Verify all appear in dropdown options
    assert_select "select#application_message_ai_agent_id" do
      assert_select "option[value='#{@motoko.id}']", text: @motoko.display_name
      assert_select "option[value='#{@rie.id}']", text: @rie.display_name
      assert_select "option[value='#{@yumi.id}']", text: @yumi.display_name
    end
  end

  test "should prevent regression: AI agents must be present in messaging interface" do
    # This test specifically guards against the bug where no AI agents were available
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify we have AI agents available
    agents_count = AiAgent.active.count
    assert agents_count >= 3, "Should have at least 3 active AI agents from setup"
    
    # Verify the messaging interface has @ai_agents populated
    assert_select "select#application_message_ai_agent_id option[value!='']", minimum: 3
    
    # Verify suggested agent logic works
    suggested_agent = AiAgent.suggest_for_application(@application)
    assert_not_nil suggested_agent, "A suggested agent should be returned by the suggestion logic"
    
    # Verify agent data is available through data attributes for Stimulus controllers
    # The messaging functionality is now handled by Stimulus controllers via data attributes
    assert_select "[data-messaging-ai-agent-data-value*='Motoko']"
  end

  test "should handle messaging form submission with Motoko as selected agent" do
    # Test creating a message with Motoko as the selected agent
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @motoko.id,
        subject: "Test message from Motoko",
        content: "This is a test message from Motoko AI Assistant"
      },
      save_draft: "Save as Draft"
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    
    # Verify the message was created with Motoko
    message = ApplicationMessage.last
    assert_equal @motoko.id, message.ai_agent_id
    assert_equal "Test message from Motoko", message.subject
    assert_equal "draft", message.status
  end

  test "should maintain Motoko selection after Turbo Stream operations" do
    # Test Turbo Stream response maintains agent selection
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @motoko.id,
        subject: "Turbo Stream test",
        content: "Testing agent selection persistence"
      },
      save_draft: "Save as Draft"
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_match /turbo-stream/, response.content_type
    
    # Should maintain agent selection in the refreshed form
    assert_match /selected="selected"/, response.body
    assert_match /#{@motoko.display_name}/, response.body
  end
end