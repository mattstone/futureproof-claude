require 'test_helper'

class DashboardApplicationManagementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @application = applications(:submitted_one)
    @application.update!(user: @user)
    
    # Create AI agent for messaging
    @ai_agent = AiAgent.find_or_create_by(name: 'Motoko') do |agent|
      agent.role_description = 'AI Financial Assistant'
      agent.avatar_filename = 'Motoko.png'
      agent.active = true
    end
    
    # Create test message from AI agent
    @message = ApplicationMessage.create!(
      application: @application,
      sender: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Welcome to Futureproof',
      content: 'Thank you for your application. We are reviewing it now.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    sign_in @user
  end

  test "dashboard shows application management section for submitted applications" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.summary-section-title', text: 'Application Management'
    assert_select '.application-management-container'
    assert_select '.application-card.enhanced'
  end

  test "application card shows basic application information" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.application-title', text: /Application #\d{6}/
    assert_select '.status-badge'
    assert_select '.overview-item'
    assert_select '.overview-value', text: @application.address
    assert_select '.overview-value', text: @application.formatted_home_value
  end

  test "application card shows message preview when messages exist" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.latest-message-preview'
    assert_select '.message-preview-content strong', text: @message.subject
    assert_select '.message-from', text: /From: #{@message.sender_name}/
  end

  test "view details button toggles application details section" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "button[data-action*='application-messages#toggleDetails']", text: /View/
    assert_select "#details-#{@application.id}"
    assert_select '.detail-group h5', text: 'Property Information'
    assert_select '.detail-group h5', text: 'Additional Information'
  end

  test "messages button shows unread message count" do
    # Create an unread message
    unread_message = ApplicationMessage.create!(
      application: @application,
      sender: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Application Update',
      content: 'Your application status has been updated.',
      status: 'sent',
      sent_at: 30.minutes.ago
    )

    get dashboard_index_path
    
    assert_response :success
    assert_select "button[data-action*='application-messages#toggleMessages']"
    assert_select '.message-count'
  end

  test "messages section displays message threads correctly" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "#messages-#{@application.id}"
    assert_select '.message-thread'
    assert_select '.message-sender-info'
    assert_select '.sender-name', text: @message.sender_name
    assert_select '.ai-badge', text: 'AI Assistant'
    assert_select '.message-subject', text: @message.processed_subject
  end

  test "message thread shows AI agent avatar when available" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.agent-avatar img[alt*="Motoko"]'
  end

  test "reply form is present but hidden by default" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "#reply-form-#{@message.id}[style*='display: none']"
    assert_select "form[action*='reply_to_message']"
    assert_select "input[name*='parent_message_id'][value='#{@message.id}']"
  end

  test "reply form has proper structure and validation" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "textarea[name*='content'][required]"
    assert_select "input[name*='subject'][required]"
    assert_select "input[type='submit'][value='Send Reply']"
    assert_select '.form-hint', text: /You can use markup/
  end

  test "empty state shown when no messages exist" do
    @message.destroy
    
    get dashboard_index_path
    
    assert_response :success
    assert_select '.empty-messages-state'
    assert_select '.empty-icon'
    assert_select 'h5', text: 'No messages yet'
  end

  test "dashboard handles applications without messages gracefully" do
    @message.destroy
    
    get dashboard_index_path
    
    assert_response :success
    assert_select '.application-card.enhanced'
    assert_no_selector '.latest-message-preview'
    assert_no_selector "button[data-action*='application-messages#toggleMessages']"
  end

  test "application details section shows complete property information" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.detail-item .detail-label', text: 'Full Address:'
    assert_select '.detail-item .detail-value', text: @application.address
    assert_select '.detail-item .detail-label', text: 'Property Value:'
    assert_select '.detail-item .detail-value', text: @application.formatted_home_value
    assert_select '.detail-item .detail-label', text: 'Ownership Type:'
  end

  test "mortgage details shown when application has mortgage" do
    mortgage = mortgages(:standard_mortgage)
    @application.update!(mortgage: mortgage)
    
    get dashboard_index_path
    
    assert_response :success
    assert_select '.detail-group h5', text: 'Mortgage Details'
    assert_select '.detail-value', text: mortgage.name
  end

  test "message status indicators display correctly" do
    @message.update!(status: 'read')
    
    get dashboard_index_path
    
    assert_response :success
    assert_select '.message-status.status-read', text: 'Read'
  end

  test "reply functionality creates new message" do
    assert_difference 'ApplicationMessage.count', 1 do
      post reply_to_message_application_path(@application), params: {
        application_message: {
          subject: "Re: #{@message.subject}",
          content: "Thank you for the update. I have a question about next steps."
        },
        parent_message_id: @message.id
      }
    end
    
    assert_redirected_to messages_application_path(@application)
    
    reply_message = ApplicationMessage.last
    assert_equal @user, reply_message.sender
    assert_equal 'customer_to_admin', reply_message.message_type
    assert_equal @message, reply_message.parent_message
  end

  test "reply form validation shows errors for invalid submissions" do
    post reply_to_message_application_path(@application), params: {
      application_message: {
        subject: "", # Empty subject should fail validation
        content: ""  # Empty content should fail validation
      },
      parent_message_id: @message.id
    }
    
    assert_response :unprocessable_entity
    assert_select '.message-thread' # Should render messages page with errors
  end

  test "responsive design classes are present" do
    get dashboard_index_path
    
    assert_response :success
    assert_select '.application-management-container'
    assert_select '.overview-grid'
    assert_select '.details-grid'
    # Check that mobile-responsive styles are included in the partial
    assert_match /@media \(max-width: 768px\)/, response.body
  end

  test "stimulus controller attributes are included in response" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "[data-controller='application-messages']"
    assert_select "[data-action*='application-messages#toggleDetails']"
    assert_select "[data-action*='application-messages#toggleMessages']"
    assert_select "[data-action*='application-messages#showReplyForm']"
    assert_select "[data-action*='application-messages#hideReplyForm']"
  end

  test "message actions are present for appropriate messages" do
    get dashboard_index_path
    
    assert_response :success
    assert_select "button[data-action*='application-messages#showReplyForm'][data-message-id='#{@message.id}']", text: /Reply/
  end

  test "mark as read button shown for unread messages" do
    @message.update!(status: 'sent')
    
    get dashboard_index_path
    
    assert_response :success
    assert_select "button[data-action*='application-messages#markAsRead'][data-message-id='#{@message.id}']", text: /Mark as Read/
  end

  test "handles multiple applications correctly" do
    # Create a second application with different data
    @second_application = Application.create!(
      user: @user,
      address: "456 Oak Street, Portland, OR",
      home_value: 750000,
      status: 'submitted'
    )
    
    get dashboard_index_path
    
    assert_response :success
    assert_select '.application-card.enhanced', count: 2
    assert_select "#application-#{@application.id}"
    assert_select "#application-#{@second_application.id}"
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password123'
      }
    }
  end
end