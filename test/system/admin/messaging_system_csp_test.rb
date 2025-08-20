require "application_system_test_case"

class Admin::MessagingSystemCspTest < ApplicationSystemTestCase
  def setup
    @admin = User.create!(
      first_name: "Admin",
      last_name: "Test",
      email: "admin-messaging@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @regular_user = User.create!(
      first_name: "John",
      last_name: "Test", 
      email: "user-messaging@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @application = Application.create!(
      user: @regular_user,
      address: "123 Messaging Street, CSP City, CSP 1001",
      home_value: 800000,
      status: 'processing',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 45
    )

    @ai_agent = AiAgent.find_or_create_by(name: 'TestMessagingAgent') do |agent|
      agent.agent_type = 'applications'
      agent.is_active = true
      agent.greeting_style = 'friendly'
      agent.display_name = 'Test Agent'
      agent.role_description = 'Customer Service Agent'
      agent.specialties = 'Application support'
    end

    sign_in_admin
  end

  test "messaging interface loads without CSP violations" do
    visit edit_admin_application_path(@application)
    
    # Check for presence of messaging interface
    assert page.has_css?('[data-controller="messaging"]'), "Messaging controller should be present"
    assert page.has_css?('textarea[data-messaging-target="contentInput"]'), "Content textarea should have messaging target"
    assert page.has_css?('input[data-messaging-target="subjectInput"]'), "Subject input should have messaging target"
    
    # Check that inline styles and scripts are gone
    assert page.has_no_css?('script'), "No inline script tags should be present"
    assert page.has_no_css?('[onclick]'), "No onclick attributes should be present"
    assert page.has_no_css?('[onchange]'), "No onchange attributes should be present"
    assert page.has_no_css?('[oninput]'), "No oninput attributes should be present"
    assert page.has_no_css?('[style]'), "No inline style attributes should be present"
  end

  test "messaging form can be filled out using Stimulus actions" do
    visit edit_admin_application_path(@application)
    
    # Select an AI agent
    select "Test Agent", from: "application_message_ai_agent_id"
    
    # Fill in subject
    fill_in "application_message_subject", with: "Test Message Subject"
    
    # Fill in content
    fill_in "application_message_content", with: "This is a **test message** with markup"
    
    # Check that the form fields are populated
    assert_field "application_message_subject", with: "Test Message Subject"
    assert_field "application_message_content", with: "This is a **test message** with markup"
  end

  test "formatting buttons work with Stimulus actions" do
    visit edit_admin_application_path(@application)
    
    # Fill in some content
    fill_in "application_message_content", with: "test"
    
    # Select the text (simulate user selecting text)
    page.execute_script("
      const textarea = document.querySelector('textarea[data-messaging-target=\"contentInput\"]');
      textarea.selectionStart = 0;
      textarea.selectionEnd = 4;
      textarea.focus();
    ")
    
    # Click bold button
    find('[data-action*="applyBold"]').click
    
    # Check that markup was applied
    assert_field "application_message_content", with: "**test**"
  end

  test "quick insert buttons work with Stimulus actions" do
    visit edit_admin_application_path(@application)
    
    # Click a quick insert button (Customer Name)
    find('button[data-field-value="{{user.first_name}}"]').click
    
    # Check that the field value was inserted
    content_value = find('textarea[data-messaging-target="contentInput"]').value
    assert_includes content_value, "{{user.first_name}}"
  end

  test "live preview updates when content changes" do
    visit edit_admin_application_path(@application)
    
    # Fill in subject and content
    fill_in "application_message_subject", with: "Preview Test Subject"
    fill_in "application_message_content", with: "Hello **{{user.first_name}}**, your application status is {{application.status_display}}."
    
    # Wait a moment for the preview to update
    sleep 0.5
    
    # Check that preview is updated with processed variables
    within '[data-messaging-target="previewSubject"]' do
      assert page.has_content?("Preview Test Subject")
    end
    
    within '[data-messaging-target="previewContent"]' do
      assert page.has_content?("Hello")
      # Should process the template variables
      assert page.has_content?("John") # user.first_name
      assert page.has_content?("Processing") # application.status_display
    end
  end

  test "agent preview updates when agent is selected" do
    visit edit_admin_application_path(@application)
    
    # Initially no agent selected
    agent_preview = find('[data-messaging-target="agentPreview"]')
    assert agent_preview[:class].exclude?('visible')
    
    # Select an AI agent
    select "Test Agent", from: "application_message_ai_agent_id"
    
    # Wait for preview to update
    sleep 0.5
    
    # Check that agent preview is now visible
    agent_preview = find('[data-messaging-target="agentPreview"]')
    assert agent_preview[:class].include?('visible')
    
    # Check that agent details are displayed
    within '[data-messaging-target="agentPreview"]' do
      assert page.has_content?("Test Agent")
      assert page.has_content?("Customer Service Agent")
    end
  end

  test "form submission works correctly" do
    visit edit_admin_application_path(@application)
    
    # Fill out the form
    select "Test Agent", from: "application_message_ai_agent_id"
    fill_in "application_message_subject", with: "Test Draft Message"
    fill_in "application_message_content", with: "This is a test draft message."
    
    # Submit as draft
    click_button "Save as Draft"
    
    # Should redirect back to the application page
    assert_current_path edit_admin_application_path(@application)
    
    # Should show a success message
    assert page.has_content?("saved"), "Should show success message"
  end

  test "no JavaScript console errors occur during interaction" do
    visit edit_admin_application_path(@application)
    
    # Get initial console logs
    initial_logs = page.driver.browser.logs.get(:browser)
    
    # Interact with the form
    select "Test Agent", from: "application_message_ai_agent_id"
    fill_in "application_message_subject", with: "Console Test"
    fill_in "application_message_content", with: "Testing console errors"
    
    # Click formatting buttons
    find('[data-action*="applyBold"]').click
    find('[data-action*="applyItalic"]').click
    find('[data-action*="applyBulletPoint"]').click
    
    # Click quick insert buttons
    find('button[data-field-value="{{user.first_name}}"]').click
    
    # Get final console logs
    final_logs = page.driver.browser.logs.get(:browser)
    
    # Filter out any non-error logs and CSP-related logs we expect
    error_logs = final_logs.select { |log| 
      log.level == "SEVERE" && 
      !log.message.include?("Content Security Policy") &&
      !log.message.include?("net::ERR_")
    }
    
    # Should not have any JavaScript errors
    assert error_logs.empty?, "Should not have JavaScript errors: #{error_logs.map(&:message).join(', ')}"
  end

  test "Turbo Stream responses work with messaging controller" do
    visit edit_admin_application_path(@application)
    
    # Fill out and submit the form
    select "Test Agent", from: "application_message_ai_agent_id"
    fill_in "application_message_subject", with: "Turbo Test Message"
    fill_in "application_message_content", with: "Testing Turbo Stream response"
    
    # Submit form
    click_button "Save as Draft"
    
    # The messaging interface should still be functional after Turbo Stream update
    assert page.has_css?('[data-controller="messaging"]'), "Messaging controller should still be present"
    
    # Should be able to interact with form again
    fill_in "application_message_subject", with: "Updated Subject"
    assert_field "application_message_subject", with: "Updated Subject"
  end

  private

  def sign_in_admin
    visit new_user_session_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "password123"
    click_button "Log in"
  end
end