require 'test_helper'

class DashboardApplicationManagementPartialTest < ActionView::TestCase
  setup do
    @user = users(:one)
    @application = applications(:submitted_one)
    @application.update!(user: @user)
    
    # Create AI agent
    @ai_agent = AiAgent.find_or_create_by(name: 'Motoko') do |agent|
      agent.role_description = 'AI Financial Assistant'
      agent.avatar_filename = 'Motoko.png'
      agent.active = true
    end
    
    # Create mortgage for testing
    @mortgage = mortgages(:standard_mortgage) if defined?(mortgages)
    @application.update!(mortgage: @mortgage) if @mortgage
    
    # Create message
    @message = ApplicationMessage.create!(
      application: @application,
      sender: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Welcome Message',
      content: 'Thank you for your application submission.',
      status: 'sent',
      sent_at: 2.hours.ago
    )
    
    @submitted_applications = [@application]
  end

  test "partial renders without errors" do
    assert_nothing_raised do
      render partial: 'dashboard/application_management'
    end
  end

  test "renders application card with basic information" do
    render partial: 'dashboard/application_management'
    
    assert_select '.application-card.enhanced'
    assert_select '.application-title', text: /Application #\d{6}/
    assert_select '.status-badge'
    assert_select '.application-date', text: /Submitted/
  end

  test "renders property overview information" do
    render partial: 'dashboard/application_management'
    
    assert_select '.overview-item'
    assert_select '.overview-label', text: 'Property'
    assert_select '.overview-value', text: @application.address
    assert_select '.overview-label', text: 'Value'
    assert_select '.overview-value', text: @application.formatted_home_value
  end

  test "renders mortgage information when present" do
    skip unless @mortgage
    
    render partial: 'dashboard/application_management'
    
    assert_select '.overview-label', text: 'Mortgage'
    assert_select '.overview-value', text: @mortgage.name
  end

  test "renders latest message preview" do
    render partial: 'dashboard/application_management'
    
    assert_select '.latest-message-preview'
    assert_select '.message-preview-content strong', text: @message.subject
    assert_select '.message-from', text: /From: #{@message.sender_name}/
  end

  test "renders expandable application details section" do
    render partial: 'dashboard/application_management'
    
    assert_select "#details-#{@application.id}[style*='display: none']"
    assert_select '.detail-group h5', text: 'Property Information'
    assert_select '.detail-group h5', text: 'Application Information'
    assert_select '.detail-label', text: 'Full Address:'
    assert_select '.detail-value', text: @application.address
  end

  test "renders messages section with message thread" do
    render partial: 'dashboard/application_management'
    
    assert_select "#messages-#{@application.id}[style*='display: none']"
    assert_select '.message-thread'
    assert_select '.message-sender-info'
    assert_select '.sender-name', text: @message.sender_name
    assert_select '.message-subject', text: @message.processed_subject
  end

  test "renders AI agent avatar in message" do
    render partial: 'dashboard/application_management'
    
    assert_select '.agent-avatar img[alt*="Motoko"]'
  end

  test "renders reply form for each message" do
    render partial: 'dashboard/application_management'
    
    assert_select "#reply-form-#{@message.id}[style*='display: none']"
    assert_select "form[data-message-id='#{@message.id}']"
    assert_select "input[name*='parent_message_id'][value='#{@message.id}']"
    assert_select "textarea[name*='content'][required]"
    assert_select "input[name*='subject'][required]"
  end

  test "renders form with proper action and method" do
    render partial: 'dashboard/application_management'
    
    expected_action = "/applications/#{@application.id}/reply_to_message"
    assert_select "form[action='#{expected_action}'][method='post']"
  end

  test "renders message actions" do
    render partial: 'dashboard/application_management'
    
    assert_select "button[onclick*='showReplyForm(#{@message.id})']", text: /Reply/
  end

  test "renders mark as read button for unread messages" do
    @message.update!(status: 'sent')
    
    render partial: 'dashboard/application_management'
    
    assert_select "button[onclick*='markAsRead(#{@message.id})']", text: /Mark as Read/
  end

  test "does not render mark as read button for read messages" do
    @message.update!(status: 'read')
    
    render partial: 'dashboard/application_management'
    
    assert_no_selector "button[onclick*='markAsRead(#{@message.id})']"
  end

  test "renders empty state when no messages exist" do
    @message.destroy
    
    render partial: 'dashboard/application_management'
    
    assert_select '.empty-messages-state'
    assert_select '.empty-icon'
    assert_select 'h5', text: 'No messages yet'
    assert_select 'p', text: /When Futureproof sends you messages/
  end

  test "handles application without mortgage gracefully" do
    @application.update!(mortgage: nil)
    
    assert_nothing_raised do
      render partial: 'dashboard/application_management'
    end
    
    assert_no_selector '.overview-label', text: 'Mortgage'
  end

  test "handles message without AI agent gracefully" do
    @message.update!(sender: @user, ai_agent: nil)
    
    render partial: 'dashboard/application_management'
    
    assert_select '.default-avatar'
    assert_no_selector '.agent-avatar img'
    assert_no_selector '.ai-badge'
  end

  test "includes all required CSS classes for styling" do
    render partial: 'dashboard/application_management'
    
    assert_select '.application-management-container'
    assert_select '.application-card.enhanced'
    assert_select '.overview-grid'
    assert_select '.latest-message-preview'
    assert_select '.details-grid'
    assert_select '.message-threads'
    assert_select '.reply-form-container'
  end

  test "includes JavaScript functions" do
    render partial: 'dashboard/application_management'
    
    assert_match /function toggleApplicationDetails/, rendered
    assert_match /function toggleApplicationMessages/, rendered
    assert_match /function showReplyForm/, rendered
    assert_match /function hideReplyForm/, rendered
    assert_match /function markAsRead/, rendered
    assert_match /function markAllAsRead/, rendered
  end

  test "renders CSS styles inline" do
    render partial: 'dashboard/application_management'
    
    assert_match /<style>/, rendered
    assert_match /\.application-management-container/, rendered
    assert_match /\.application-card\.enhanced/, rendered
    assert_match /@media \(max-width: 768px\)/, rendered
  end

  test "handles multiple applications" do
    second_application = Application.create!(
      user: @user,
      address: "789 Pine Street, Seattle, WA",
      home_value: 900000,
      status: 'submitted'
    )
    
    @submitted_applications = [@application, second_application]
    
    render partial: 'dashboard/application_management'
    
    assert_select '.application-card.enhanced', count: 2
    assert_select "#application-#{@application.id}"
    assert_select "#application-#{second_application.id}"
  end

  test "renders message count badge when unread messages exist" do
    # Create additional unread message
    ApplicationMessage.create!(
      application: @application,
      sender: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Update Required',
      content: 'Please provide additional documentation.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    render partial: 'dashboard/application_management'
    
    assert_select '.message-count'
    assert_select "button[onclick*='toggleApplicationMessages']", text: /Messages/
  end

  test "renders toggle buttons with correct onclick functions" do
    render partial: 'dashboard/application_management'
    
    assert_select "button[onclick='toggleApplicationDetails(#{@application.id})']"
    assert_select "button[onclick='toggleApplicationMessages(#{@application.id})']"
  end

  test "form includes CSRF protection" do
    render partial: 'dashboard/application_management'
    
    # Rails forms should include authenticity token
    assert_select "input[name='authenticity_token']"
  end

  test "truncates long property addresses in overview" do
    long_address = "A" * 100 + " Street, Very Long City Name, State"
    @application.update!(address: long_address)
    
    render partial: 'dashboard/application_management'
    
    # Should be truncated to 40 characters
    assert_select '.overview-value', text: /^A{37}\.\.\./
  end

  test "formats message content properly" do
    @message.update!(content: "**Bold text** and *italic text* with bullet points:\n- Point 1\n- Point 2")
    
    render partial: 'dashboard/application_management'
    
    # Content should be processed as HTML
    assert_select '.message-body'
  end
end