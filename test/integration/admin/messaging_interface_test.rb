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
end