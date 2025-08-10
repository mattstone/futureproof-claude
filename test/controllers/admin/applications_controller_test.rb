require 'test_helper'

class Admin::ApplicationsControllerTest < ActionDispatch::IntegrationTest
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
      first_name: 'Customer',
      last_name: 'User',
      admin: false,
      terms_accepted: true,
      terms_version: 1
    )
    
    @application = Application.create!(
      user: @customer,
      address: '123 Test St, Test City, TC 12345',
      home_value: 500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
    )
    
    @ai_agent = AiAgent.create!(
      name: 'test_agent',
      agent_type: 'applications',
      description: 'Test agent for messaging',
      specialties: 'Testing',
      avatar_filename: 'Motoko.png',
      is_active: true
    )
    
    sign_in @admin
  end
  
  test "should show application with messaging interface" do
    get admin_application_path(@application)
    
    assert_response :success
    assert_select 'h3', text: 'Send Message to Customer'
    assert_select 'form[action=?]', create_message_admin_application_path(@application)
    assert_select 'input[name=from_view][value=show]', 1
  end
  
  test "should show edit application with messaging interface" do
    get edit_admin_application_path(@application)
    
    assert_response :success
    assert_select 'h3', text: 'Send Message to Customer'
    assert_select 'form[action=?]', create_message_admin_application_path(@application)
    assert_select 'input[name=from_view][value=edit]', 1
  end
  
  test "should create message as draft from show view" do
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: 'Test Message',
          content: 'Test content',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'Message saved as draft!', flash[:notice]
    
    message = ApplicationMessage.last
    assert_equal 'Test Message', message.subject
    assert_equal 'Test content', message.content
    assert_equal 'draft', message.status
    assert_equal 'admin_to_customer', message.message_type
    assert_equal @admin, message.sender
  end
  
  test "should create message as draft from edit view" do
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'edit',
        application_message: {
          subject: 'Test Message',
          content: 'Test content',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to edit_admin_application_path(@application)
    assert_equal 'Message saved as draft!', flash[:notice]
  end
  
  test "should send message immediately from show view" do
    
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        send_now: 'Send Message',
        application_message: {
          subject: 'Test Message',
          content: 'Test content',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'Message sent successfully!', flash[:notice]
  end
  
  test "should send message immediately from edit view" do
    
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'edit',
        send_now: 'Send Message',
        application_message: {
          subject: 'Test Message',
          content: 'Test content',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to edit_admin_application_path(@application)
    assert_equal 'Message sent successfully!', flash[:notice]
  end
  
  test "should handle validation errors in show view" do
    post create_message_admin_application_path(@application), params: {
      from_view: 'show',
      application_message: {
        subject: '', # Invalid - required field
        content: 'Test content',
        ai_agent_id: @ai_agent.id
      }
    }
    
    assert_response :unprocessable_entity
    assert_select 'h2', text: /Application ##{@application.id}/  # Verify show view content
    assert_select '.alert-danger'
  end
  
  test "should handle validation errors in edit view" do
    post create_message_admin_application_path(@application), params: {
      from_view: 'edit',
      application_message: {
        subject: '', # Invalid - required field
        content: 'Test content',
        ai_agent_id: @ai_agent.id
      }
    }
    
    assert_response :unprocessable_entity
    assert_select 'h2', text: /Edit Application ##{@application.id}/  # Verify edit view content
    assert_select '.alert-danger'
  end
  
  test "should send draft message" do
    message = @application.application_messages.create!(
      subject: 'Draft Message',
      content: 'Draft content',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    patch send_message_admin_application_path(@application, message_id: message.id)
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'Message sent successfully!', flash[:notice]
  end
  
  test "should handle non-draft message sending" do
    message = @application.application_messages.create!(
      subject: 'Sent Message',
      content: 'Already sent content',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'sent' # Already sent, should fail
    )
    
    patch send_message_admin_application_path(@application, message_id: message.id)
    
    assert_redirected_to admin_application_path(@application)
    assert_equal 'Failed to send message.', flash[:alert]
  end
  
  test "should display existing messages in both views" do
    message = @application.application_messages.create!(
      subject: 'Existing Message',
      content: 'Existing content',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'sent'
    )
    
    # Test show view
    get admin_application_path(@application)
    assert_response :success
    assert_select '.message-thread'
    assert_select '.message-subject', text: /Existing Message/
    
    # Test edit view
    get edit_admin_application_path(@application)
    assert_response :success
    assert_select '.message-thread'
    assert_select '.message-subject', text: /Existing Message/
  end
  
  test "should load AI agents for message form" do
    get admin_application_path(@application)
    
    assert_response :success
    assert_select 'select[name="application_message[ai_agent_id]"]'
    assert_select 'option[value=?]', @ai_agent.id.to_s
  end
  
  test "should include messaging assets in both views" do
    get admin_application_path(@application)
    assert_response :success
    # Check for JavaScript function existence (basic check)
    assert_select 'script', text: /updateAgentPreview/
    
    get edit_admin_application_path(@application)
    assert_response :success
    assert_select 'script', text: /updateAgentPreview/
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