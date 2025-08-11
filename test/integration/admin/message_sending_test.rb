require 'test_helper'

class Admin::MessageSendingTest < ActionDispatch::IntegrationTest
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
      email: 'john.doe@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      admin: false,
      terms_accepted: true,
      terms_version: 1,
      country_of_residence: 'Australia'
    )
    
    @application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
    )
    
    @ai_agent = AiAgent.create!(
      name: 'motoko',
      agent_type: 'applications',
      description: 'Application processing specialist',
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
  
  test "should successfully send message with template variables" do
    message_params = {
      application_message: {
        ai_agent_id: @ai_agent.id,
        subject: 'Application Update for {{user.first_name}}',
        content: 'Hello {{user.first_name}}, your application at {{application.address}} is being processed.'
      },
      send_now: 'Send Message'
    }
    
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: message_params
    end
    
    message = ApplicationMessage.last
    assert_equal 'sent', message.status
    assert_not_nil message.sent_at
    assert message.sent?
    
    # Test template variable processing
    assert_equal 'Application Update for John', message.processed_subject
    assert_includes message.content_html, 'Hello John'
    assert_includes message.content_html, '123 Main Street, Sydney, NSW 2000'
  end
  
  test "should save as draft when requested" do
    message_params = {
      application_message: {
        ai_agent_id: @ai_agent.id,
        subject: 'Draft Message',
        content: 'This is a draft message with **bold** text.'
      },
      save_draft: 'Save as Draft'
    }
    
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: message_params
    end
    
    message = ApplicationMessage.last
    assert_equal 'draft', message.status
    assert_nil message.sent_at
    assert message.draft?
  end
  
  test "should send draft message later" do
    # Create draft message
    draft_message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      subject: 'Draft Message',
      content: 'Draft content',
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    # Send the draft
    patch send_message_admin_application_path(@application, message_id: draft_message.id)
    
    draft_message.reload
    assert_equal 'sent', draft_message.status
    assert_not_nil draft_message.sent_at
    assert draft_message.sent?
  end
  
  test "should handle message sending errors gracefully" do
    # Create a scenario that might cause an error by temporarily breaking the mailer
    original_method = ApplicationMailer.method(:message_notification)
    
    # Mock a failing mailer
    ApplicationMailer.define_singleton_method(:message_notification) do |_|
      raise StandardError, "Simulated mailer error"
    end
    
    begin
      message = ApplicationMessage.create!(
        application: @application,
        sender: @admin,
        ai_agent: @ai_agent,
        subject: 'Test Error Handling',
        content: 'Test content',
        message_type: 'admin_to_customer',
        status: 'draft'
      )
      
      # Attempt to send - should handle error gracefully
      result = message.send_message!
      
      # Should return false on error
      assert_equal false, result
      
      # Message should remain as draft due to error
      message.reload
      assert_equal 'draft', message.status
    ensure
      # Restore original mailer method
      ApplicationMailer.define_singleton_method(:message_notification, original_method)
    end
  end
  
  test "should process markup correctly in message content" do
    message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      subject: 'Markup Test',
      content: "**Bold text** and *italic text*\n- First item\n- Second item",
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    html_content = message.content_html
    
    # Check bold formatting
    assert_includes html_content, '<strong>Bold text</strong>'
    
    # Check italic formatting
    assert_includes html_content, '<em>italic text</em>'
    
    # Check bullet list formatting
    assert_includes html_content, '<ul>'
    assert_includes html_content, '<li>First item</li>'
    assert_includes html_content, '<li>Second item</li>'
    assert_includes html_content, '</ul>'
  end
  
  test "should handle validation at model level" do
    # Test model validation directly
    message = ApplicationMessage.new(
      application: @application,
      sender: @admin,
      message_type: 'admin_to_customer',
      status: 'draft'
      # Missing required fields: subject, content, ai_agent
    )
    
    assert_not message.valid?
    assert_includes message.errors[:subject], "can't be blank"
    assert_includes message.errors[:content], "can't be blank"
    
    # Test that message with proper fields is valid
    valid_message = ApplicationMessage.new(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      subject: 'Valid Subject',
      content: 'Valid content',
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert valid_message.valid?
  end
  
  test "should create secure token for email links" do
    # Mock the ApplicationMailer to capture the generated token
    captured_token = nil
    
    ApplicationMailer.define_singleton_method(:message_notification) do |message|
      # Access the @application_link instance variable to get the token
      mailer = new
      mailer.instance_variable_set(:@message, message)
      mailer.instance_variable_set(:@application, message.application)
      mailer.instance_variable_set(:@user, message.application.user)
      
      # Generate token
      token = mailer.send(:generate_secure_token)
      captured_token = token
      
      # Return mock mail object
      mock_mail = Object.new
      def mock_mail.deliver_now; end
      mock_mail
    end
    
    message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      subject: 'Token Test',
      content: 'Test content',
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    result = message.send_message!
    assert result
    
    # Verify token was generated
    assert_not_nil captured_token
    assert captured_token.length > 0
    
    # Test token can be decrypted
    payload = SecureTokenEncryptor.decrypt_and_verify(captured_token)
    assert_equal @application.id, payload['application_id']
    assert_equal @customer.id, payload['user_id']
    assert payload['expires_at'] > Time.current.to_i
  end
  
  test "should handle message threading correctly" do
    # Create parent message
    parent_message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      subject: 'Parent Message',
      content: 'Original message',
      message_type: 'admin_to_customer',
      status: 'sent'
    )
    
    # Create reply
    reply_message = ApplicationMessage.create!(
      application: @application,
      sender: @customer,
      parent_message: parent_message,
      subject: 'Re: Parent Message',
      content: 'Reply message',
      message_type: 'customer_to_admin',
      status: 'sent'
    )
    
    # Test thread relationships
    assert_equal parent_message, reply_message.parent_message
    assert_includes parent_message.replies, reply_message
    assert_equal parent_message, reply_message.root_message
    
    thread_messages = parent_message.thread_messages
    assert_includes thread_messages, parent_message
    assert_includes thread_messages, reply_message
  end
  
  teardown do
    # Clean up any test files
    File.delete('/Users/zen/projects/futureproof/futureproof/test_message_sending.rb') if File.exist?('/Users/zen/projects/futureproof/futureproof/test_message_sending.rb')
  end
end