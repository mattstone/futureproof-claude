require 'test_helper'

class Admin::MessagingInterfaceTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    @application = applications(:submitted_application)
    
    # Create an AI agent for testing
    @ai_agent = AiAgent.create!(
      name: 'TestBot',
      agent_type: 'applications',
      avatar_filename: 'Motoko.png',
      greeting_style: 'friendly',
      is_active: true,
      specialties: 'Application Processing'
    )
    
    # Log in as admin
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
  end

  test "should display clear preview disclaimer in messaging interface" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should show preview disclaimer
    assert_select '.preview-disclaimer'
    assert_select '.preview-disclaimer', /Preview Only.*This shows how the email will appear to the customer/
    
    # Should include eye emoji and proper styling
    assert_match /👁️/, response.body
    assert_match /background-color: #fef3c7/, response.body
  end

  test "should display preview button with clear indicators" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should show the preview button with proper styling
    assert_match /View Application & Reply/, response.body
    assert_match /opacity: 0\.7/, response.body
    
    # Should include preview indicator text
    assert_match /Preview - Customer will see this button in the actual email/, response.body
  end

  test "should display prominent action buttons section" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should show the prominent action buttons section with proper layout
    assert_match /📤 Ready to send your message\?/, response.body
    assert_match /Choose how you want to handle this message/, response.body
    
    # Should have both save and send buttons
    assert_select 'input[type="submit"][value="Save as Draft"]'
    assert_select 'input[type="submit"][value="Send Message Now"]'
    
    # Should include helpful tip underneath buttons
    assert_match /💡.*Tip.*Save as draft to review later/, response.body
    
    # Should have proper CSS classes for structure
    assert_select '.actions-header'
    assert_select '.actions-description'
    assert_select '.actions-buttons'
    assert_select '.actions-tip'
  end

  test "should have proper visual hierarchy between preview and actions" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Preview section should come before action buttons
    preview_position = response.body.index('Live Preview (Email Layout)')
    actions_position = response.body.index('📤 Ready to send your message?')
    
    assert preview_position < actions_position, "Preview should appear before action buttons"
    
    # Action buttons should have distinctive styling via CSS classes
    assert_select '.message-actions-container'
  end

  test "should differentiate send button from save button" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have proper CSS classes for differentiation
    assert_select 'input.draft-btn[value="Save as Draft"]'
    assert_select 'input.send-btn[value="Send Message Now"]'
    
    # Should have the CSS classes that differentiate the buttons
    assert_match /\.send-btn/, response.body
    assert_match /\.draft-btn/, response.body
  end

  test "should show messaging interface in show view" do
    get admin_application_path(@application)
    assert_response :success
    
    # Should display the same messaging interface elements
    assert_select '.preview-disclaimer'
    assert_match /📤 Ready to send your message\?/, response.body
  end

  test "should handle missing AI agent gracefully" do
    # Delete messages that reference AI agents first
    ApplicationMessage.destroy_all
    ContractMessage.destroy_all
    AiAgent.destroy_all
    
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should still show the interface even without AI agents
    assert_select '.preview-disclaimer'
    assert_match /📤 Ready to send your message\?/, response.body
  end

  test "should maintain proper form functionality" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have proper form setup
    assert_select 'form.message-form'
    assert_select 'form input[name="save_draft"]'
    assert_select 'form input[name="send_now"]'
    
    # Should have required fields
    assert_select 'input[required]', minimum: 1 # at least subject is required
    assert_select 'textarea[required]', count: 1 # content
  end

  test "should include proper accessibility features" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have proper labels for form elements
    assert_select 'label[for]'
    
    # Should have descriptive text for buttons
    assert_match /Save as draft to review later/, response.body
    assert_match /send now to deliver immediately/, response.body
  end

  test "should display AI agent selection interface on initial load" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have AI agent selection dropdown
    assert_select 'select#application_message_ai_agent_id[required]'
    assert_select 'select#application_message_ai_agent_id option', text: 'Select AI Agent...'
    assert_select 'select#application_message_ai_agent_id option', text: @ai_agent.display_name
    
    # Should have agent preview div
    assert_select 'div#agent-preview.agent-preview'
    assert_select 'div#agent-preview .agent-info'
    assert_select 'div#agent-preview .agent-details'
    assert_select 'div#agent-preview .agent-name'
    assert_select 'div#agent-preview .agent-role'
    assert_select 'div#agent-preview .agent-specialties'
    
    # Should have onchange handler for agent selection
    assert_select 'select[onchange="updateAgentPreview(this)"]'
  end

  test "should maintain AI agent interface after sending message via Turbo Stream" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Send a message via Turbo Stream (which should maintain the interface)
    post create_message_admin_application_path(@application), params: {
      application_message: {
        ai_agent_id: @ai_agent.id,
        subject: "Test Subject",
        content: "Test content"
      },
      send_now: "Send Message Now"
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_match /turbo-stream/, response.content_type
    
    # Verify the response contains the AI agent selection interface
    assert_match /ai-agent-selection/, response.body
    assert_match /agent-preview/, response.body
    assert_match /updateAgentPreview/, response.body
    
    # Should contain the initialization script
    assert_match /updatePreview\(\)/, response.body
    assert_match /addEventListener\('input'/, response.body
    
    # Should have the agent dropdown with proper structure
    assert_match /application_message_ai_agent_id/, response.body
    assert_match /Select AI Agent\.\.\./, response.body
  end

  test "should include JavaScript initialization for messaging interface" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should include the messaging assets with JavaScript functions
    assert_match /function updateAgentPreview/, response.body
    assert_match /function updatePreview/, response.body
    assert_match /function initializeForm/, response.body
    
    # Should have event listeners setup
    assert_match /addEventListener\('DOMContentLoaded'/, response.body
    assert_match /addEventListener\('turbo:stream-connected'/, response.body
    
    # Should have agent data available to JavaScript
    assert_match /window\.aiAgentData/, response.body
    assert_match /window\.applicationData/, response.body
  end

  test "should handle live preview functionality" do
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Should have live preview section
    assert_select '.live-preview-section'
    assert_select '#message-preview'
    assert_select '#preview-subject'
    assert_select '#preview-content'
    assert_select '#preview-agent-header'
    assert_select '#preview-agent-name'
    assert_select '#preview-agent-role'
    
    # Should have template variable processing functions
    assert_match /function processTemplateVariables/, response.body
    assert_match /function markupToHtml/, response.body
    
    # Should have email preview with agent information
    assert_match /preview-agent-avatar/, response.body
    assert_match /preview-agent-fallback/, response.body
  end
end