require 'test_helper'

class Admin::MessagingWorkflowTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  
  setup do
    # Create a mock mailer to prevent actual email sending during tests
    mock_mail = Object.new
    def mock_mail.deliver_now; end
    ApplicationMailer.define_singleton_method(:message_notification) { |_| mock_mail }
    @admin = User.create!(
      email: 'admin@example.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      terms_accepted: true,
      terms_version: 1
    )
    
    @customer = User.create!(
      email: 'customer@example.com', 
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      admin: false,
      terms_accepted: true,
      terms_version: 1
    )
    
    @application = Application.create!(
      user: @customer,
      address: '123 Main Street, Anytown, AT 12345',
      home_value: 750000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
    )
    
    @ai_agent = AiAgent.create!(
      name: 'customer_service',
      agent_type: 'applications',
      description: 'Handles customer inquiries and updates',
      specialties: 'Customer service, application status updates',
      avatar_filename: 'Motoko.png',
      is_active: true
    )
    
    # Sign in as admin
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: 'password123'
      }
    }
  end
  
  test "complete messaging workflow from application show view" do
    # 1. Navigate to application show view
    get admin_application_path(@application)
    assert_response :success
    
    # Verify messaging interface is present
    assert_select 'h3', text: 'Send Message to Customer'
    assert_select 'form[action=?]', create_message_admin_application_path(@application)
    assert_select 'input[name=from_view][value=show]'
    
    # 2. Create a draft message
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: 'Application Status Update',
          content: 'Hello {{user.first_name}}, your application for {{application.address}} has been reviewed.',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    # Verify redirect back to show view and success message
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    assert_equal 'Message saved as draft!', flash[:notice]
    
    # 3. Verify draft message appears in message history
    draft_message = ApplicationMessage.last
    assert_equal 'draft', draft_message.status
    assert_equal @admin, draft_message.sender
    assert_equal @ai_agent, draft_message.ai_agent
    
    # Check that draft message is displayed
    assert_select '.message-thread' do
      assert_select '.message-status.status-draft', text: 'Draft'
      assert_select '.message-subject', text: /Application Status Update/
    end
    
    # 4. Send the draft message
    
    patch send_message_admin_application_path(@application, message_id: draft_message.id)
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    
    assert_equal 'Message sent successfully!', flash[:notice]
  end
  
  test "complete messaging workflow from application edit view" do
    # 1. Navigate to application edit view
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Verify messaging interface is present alongside edit form
    assert_select 'h2', text: /Edit Application ##{@application.id}/
    assert_select 'h3', text: 'Send Message to Customer'
    assert_select 'input[name=from_view][value=edit]'
    
    # 2. Send message immediately from edit view
    
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'edit',
        send_now: 'Send Message',
        application_message: {
          subject: 'Documentation Required',
          content: 'Hi {{user.first_name}}, we need additional documents for {{application.address}}.',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    # Verify redirect back to edit view
    assert_redirected_to edit_admin_application_path(@application)
    follow_redirect!
    assert_equal 'Message sent successfully!', flash[:notice]
    
    # 3. Verify message was created with correct attributes
    sent_message = ApplicationMessage.last
    assert_equal 'sent', sent_message.status
    assert_equal 'admin_to_customer', sent_message.message_type
    assert_equal @admin, sent_message.sender
    assert_equal @application, sent_message.application
  end
  
  test "messaging interface displays field helpers correctly" do
    get admin_application_path(@application)
    
    # Verify field helper buttons are present
    assert_select '.field-helpers' do
      assert_select '.helper-btn', text: 'Customer Name'
      assert_select '.helper-btn', text: 'Property Address'
      assert_select '.helper-btn', text: 'Home Value'
      assert_select '.helper-btn', text: 'Application Status'
    end
    
    # Verify JavaScript functions are included
    assert_select 'script', text: /insertField/
    assert_select 'script', text: /updateAgentPreview/
  end
  
  test "messaging interface handles validation errors gracefully" do
    # Try to create message with missing required fields from show view
    post create_message_admin_application_path(@application), params: {
      from_view: 'show',
      application_message: {
        subject: '', # Required field left empty
        content: 'Some content',
        ai_agent_id: @ai_agent.id
      }
    }
    
    # Should render show template with errors
    assert_response :unprocessable_entity
    assert_select 'h2', text: /Application ##{@application.id}/  # Verify show view content
    assert_select '.alert-danger'
    
    # Verify application details are still shown
    assert_select 'h2', text: /Application ##{@application.id}/
    assert_select '.detail-row', text: /#{@customer.display_name}/
  end
  
  test "AI agent preview functionality works" do
    get admin_application_path(@application)
    
    # Verify agent preview container exists
    assert_select '#agent-preview.agent-preview[style="display: none;"]'
    assert_select '.agent-info' do
      assert_select '.agent-avatar'
      assert_select '.agent-name'
      assert_select '.agent-role'
      assert_select '.agent-specialties'
    end
    
    # Verify agent data is passed to JavaScript
    assert_select 'script', text: /window\.agentData/
  end
  
  test "message history displays correctly with multiple message types" do
    # Create various types of messages
    draft_message = @application.application_messages.create!(
      subject: 'Draft Message',
      content: 'This is a draft',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    sent_message = @application.application_messages.create!(
      subject: 'Sent Message',
      content: 'This was sent',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'sent'
    )
    
    get admin_application_path(@application)
    
    # Verify both messages are displayed
    assert_select '.message-thread', 2
    
    # Verify draft message has send button
    assert_select '.message-thread' do |elements|
      draft_thread = elements.find { |el| el.text.include?('Draft Message') }
      assert draft_thread.css('.admin-btn-success').any?, "Draft message should have send button"
    end
    
    # Verify sent message doesn't have send button
    assert_select '.message-thread' do |elements|
      sent_thread = elements.find { |el| el.text.include?('Sent Message') }
      assert sent_thread.css('.admin-btn-success').empty?, "Sent message should not have send button"
    end
  end
  
  test "messaging works consistently between show and edit views" do
    # Create a message from edit view
    get edit_admin_application_path(@application)
    
    post create_message_admin_application_path(@application), params: {
      from_view: 'edit',
      application_message: {
        subject: 'Message from Edit',
        content: 'Content from edit view',
        ai_agent_id: @ai_agent.id
      }
    }
    
    # Navigate to show view and verify message is visible
    get admin_application_path(@application)
    assert_select '.message-subject', text: /Message from Edit/
    
    # Create another message from show view
    post create_message_admin_application_path(@application), params: {
      from_view: 'show',
      application_message: {
        subject: 'Message from Show',
        content: 'Content from show view',
        ai_agent_id: @ai_agent.id
      }
    }
    
    # Navigate to edit view and verify both messages are visible
    get edit_admin_application_path(@application)
    assert_select '.message-subject', text: /Message from Edit/
    assert_select '.message-subject', text: /Message from Show/
  end
end