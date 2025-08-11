require 'application_system_test_case'

class DashboardMessageInteractionsTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @application = Application.create!(
      user: @user,
      address: "123 Test Street, Portland, OR",
      home_value: 800000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )
    
    @ai_agent = AiAgent.find_or_create_by(name: 'Motoko') do |agent|
      agent.avatar_filename = 'Motoko.png'
      agent.agent_type = 'applications'
      agent.is_active = true
      agent.greeting_style = 'friendly'
    end
    
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-system@example.com", 
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Your application status',
      content: 'We have received your application and are currently reviewing it. Please expect updates within 5-7 business days.',
      status: 'sent',
      sent_at: 2.hours.ago
    )
  end

  test "user can expand and collapse message section" do
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Messages section should be hidden initially
    assert_not page.has_selector?("#messages-#{@application.id}", visible: true)
    
    # Click messages button to expand
    click_button "Messages"
    
    # Messages section should now be visible
    assert page.has_selector?("#messages-#{@application.id}", visible: true)
    assert page.has_text?(@message.subject)
    assert page.has_text?(@message.sender_name)
    
    # Click again to collapse  
    click_button "Messages"
    
    # Messages section should be hidden again
    assert_not page.has_selector?("#messages-#{@application.id}", visible: true)
  end

  test "user can show and hide reply form" do
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Expand messages section first
    click_button "Messages"
    
    # Reply form should be hidden initially
    assert_not page.has_selector?("#reply-form-#{@message.id} form", visible: true)
    
    # Click reply button
    click_button "Reply"
    
    # Reply form should now be visible
    assert page.has_selector?("#reply-form-#{@message.id} form", visible: true)
    assert page.has_field?("application_message[subject]")
    assert page.has_field?("application_message[content]")
    
    # Click cancel to hide form
    click_button "Cancel"
    
    # Reply form should be hidden again
    assert_not page.has_selector?("#reply-form-#{@message.id} form", visible: true)
  end

  test "user can submit reply via Turbo without page refresh" do
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Expand messages and show reply form
    click_button "Messages"
    click_button "Reply"
    
    # Fill out reply form
    fill_in "application_message[subject]", with: "Re: Your application status"
    fill_in "application_message[content]", with: "Thank you for the update. I look forward to hearing from you soon."
    
    # Track current URL to ensure no navigation occurs
    original_url = current_url
    
    # Submit form
    assert_difference -> { ApplicationMessage.count }, 1 do
      click_button "Send Reply"
    end
    
    # Should stay on same page
    assert_equal original_url, current_url
    
    # Should show success message
    assert page.has_text?("Your reply has been sent successfully!")
    
    # Verify reply was created correctly
    reply = ApplicationMessage.last
    assert_equal @user, reply.sender
    assert_equal 'customer_to_admin', reply.message_type
    assert_equal @message, reply.parent_message
  end

  test "form validation errors display without page refresh" do
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Expand messages and show reply form
    click_button "Messages"  
    click_button "Reply"
    
    # Submit form with empty required fields
    original_url = current_url
    
    assert_no_difference -> { ApplicationMessage.count } do
      click_button "Send Reply"
    end
    
    # Should stay on same page
    assert_equal original_url, current_url
    
    # Should show validation errors
    assert page.has_selector?(".form-errors")
    assert page.has_text?("can't be blank")
    
    # Form should still be visible with errors
    assert page.has_selector?("#reply-form-#{@message.id} form", visible: true)
  end

  test "unread message badge shows correct count and updates" do
    # Create additional unread messages
    ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Document request',
      content: 'Please provide additional documentation.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    sign_in_user
    visit dashboard_path
    
    # Should show unread badge with count of 2
    within('.sidebar-nav') do
      assert page.has_selector?('.unread-badge', text: '2')
    end
    
    # Navigate to applications to view messages
    click_link "Applications"
    
    # Badge should still be visible
    assert page.has_selector?('.unread-badge', text: '2')
  end

  test "message content renders with proper formatting" do
    @message.update!(
      content: "Hello **#{@user.first_name}**!\n\n*Important updates:*\n\n- Your application is under review\n- We may request additional documents\n- Expected completion: 5-7 business days"
    )
    
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Expand messages section
    click_button "Messages"
    
    # Should show processed content with HTML formatting
    within('.message-content') do
      assert page.has_selector?('strong', text: @user.first_name)
      assert page.has_selector?('em', text: 'Important updates:')
      assert page.has_selector?('li', text: 'Your application is under review')
      assert page.has_selector?('li', text: 'We may request additional documents')
    end
  end

  test "AI agent information displays correctly in message thread" do
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Expand messages section
    click_button "Messages"
    
    # Should show AI agent name and badge
    within('.message-thread') do
      assert page.has_text?('Motoko')
      assert page.has_selector?('.ai-badge', text: 'AI Assistant')
      assert page.has_text?('AI Financial Assistant')
      
      # Should show avatar or fallback icon
      assert page.has_selector?('.agent-avatar img, .default-avatar')
    end
  end

  test "message timestamp displays in readable format" do
    sign_in_user  
    visit dashboard_path(section: 'applications')
    
    # Expand messages section
    click_button "Messages"
    
    # Should show formatted timestamp
    within('.message-meta') do
      assert page.has_selector?('.message-time')
      # Time should be in human-readable format (exact format depends on helper method)
      assert page.has_text?(Regexp.new(/\d+:\d+/)) # Should contain time like "2:30" 
    end
  end

  test "multiple applications show separate message sections" do
    # Create second application
    second_app = Application.create!(
      user: @user,
      address: "456 Oak Street, Seattle, WA",
      home_value: 600000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 67
    )
    
    second_message = ApplicationMessage.create!(
      application: second_app,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Second application received',
      content: 'We have received your second application.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Should show both applications
    assert page.has_selector?("#application-#{@application.id}")
    assert page.has_selector?("#application-#{second_app.id}")
    
    # Each should have separate Messages buttons
    within("#application-#{@application.id}") do
      click_button "Messages"
      assert page.has_text?(@message.subject)
    end
    
    within("#application-#{second_app.id}") do  
      click_button "Messages"
      assert page.has_text?(second_message.subject)
    end
  end

  test "empty messages state displays when no messages exist" do
    @message.destroy
    
    sign_in_user
    visit dashboard_path(section: 'applications')
    
    # Should not show Messages button when no messages exist
    assert_not page.has_button?("Messages")
    
    # If we programmatically expand the messages section, should show empty state
    page.execute_script("document.getElementById('messages-#{@application.id}').style.display = 'block'")
    
    within("#messages-#{@application.id}") do
      assert page.has_selector?('.empty-messages-state')
      assert page.has_text?('No messages yet')
      assert page.has_text?('Futureproof sends you messages')
    end
  end

  private

  def sign_in_user
    visit new_user_session_path
    fill_in "Email", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    
    # Wait for successful sign in
    assert page.has_text?("Dashboard")
  end
end