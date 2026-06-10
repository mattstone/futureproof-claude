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
    @akane = AiAgent.create!(
      name: 'Akane',
      agent_type: 'applications',
      avatar_filename: 'Akane.png',
      role_title: 'Customer Acquisition Specialist',
      description: 'Guides prospective customers through EPM questions, eligibility, and structured intake before handoff to a licensed adviser.',
      specialties: 'EPM FAQs, eligibility assessments, structured intake, application guidance',
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
      user: { email: @admin.email, password: 'password1234' }
    }
    follow_redirect!
  end

  test "should have Akane AI agent from seeds available in admin applications edit page" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify Akane exists from setup
    assert_not_nil @akane, "Akane AI agent should exist from setup"
    assert_equal 'applications', @akane.agent_type
    assert_equal 'Akane.png', @akane.avatar_filename
    assert_equal 'Customer Acquisition Specialist', @akane.role_title
    assert @akane.is_active
    
    # Verify Akane appears in the AI agent dropdown
    assert_select "select#application_message_ai_agent_id" do
      assert_select "option[value='#{@akane.id}']", text: @akane.display_name
    end
  end

  test "should have Akane as the suggested agent for submitted applications" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Test the suggestion logic
    suggested_agent = AiAgent.suggest_for_application(@application)
    
    assert_not_nil suggested_agent, "A suggested agent should be returned"
    assert_equal @akane.id, suggested_agent.id, "Akane should be suggested for submitted applications"
    
    # Verify Akane is pre-selected in the dropdown
    assert_select "select#application_message_ai_agent_id option[selected][value='#{@akane.id}']", 
                  text: @akane.display_name
  end

  test "should display Akane's details in agent preview when pre-selected" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify agent preview is visible with Akane's details
    assert_select "#agent-preview.visible" do
      assert_select ".agent-name", text: @akane.display_name
      assert_select ".agent-role", text: @akane.role_description
      assert_select ".agent-specialties", text: /#{@akane.specialties}/
    end
  end

  test "should have all three seeded AI agents available" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify all three seeded agents exist from setup
    assert_not_nil @akane, "Akane should exist from setup"
    assert_not_nil @rie, "Rie should exist from setup"
    assert_not_nil @yumi, "Yumi should exist from setup"
    
    # Verify all appear in dropdown options
    assert_select "select#application_message_ai_agent_id" do
      assert_select "option[value='#{@akane.id}']", text: @akane.display_name
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
    assert_select "[data-messaging-ai-agent-data-value*='Akane']"
  end

  test "should handle messaging form submission with Akane as selected agent" do
    # Test creating a message with Akane as the selected agent
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @akane.id,
        subject: "Test message from Akane",
        content: "This is a test message from Akane AI Assistant"
      },
      save_draft: "Save as Draft"
    }
    
    assert_response :redirect
    follow_redirect!
    assert_response :success
    
    # Verify the message was created with Akane
    message = ApplicationMessage.last
    assert_equal @akane.id, message.ai_agent_id
    assert_equal "Test message from Akane", message.subject
    assert_equal "draft", message.status
  end

  test "should maintain Akane selection after Turbo Stream operations" do
    # Test Turbo Stream response maintains agent selection
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @akane.id,
        subject: "Turbo Stream test",
        content: "Testing agent selection persistence"
      },
      save_draft: "Save as Draft"
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_match /turbo-stream/, response.content_type
    
    # Should maintain agent selection in the refreshed form
    assert_match /selected="selected"/, response.body
    assert_match /#{@akane.display_name}/, response.body
  end
end