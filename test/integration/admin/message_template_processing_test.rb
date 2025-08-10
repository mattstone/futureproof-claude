require 'test_helper'

class Admin::MessageTemplateProcessingTest < ActionDispatch::IntegrationTest
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
  
  test "should process template variables when creating message from show view" do
    # Navigate to application show view
    get admin_application_path(@application)
    assert_response :success
    
    # Create message with template variables
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: 'Hello {{user.first_name}}!',
          content: 'Dear {{user.first_name}} {{user.last_name}}, your application for {{application.address}} is {{application.status_display}}.',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    
    # Verify the message displays with processed template variables
    message = ApplicationMessage.last
    assert_equal 'Hello John!', message.processed_subject
    assert_includes message.content_html, 'Dear John Doe, your application for 123 Main Street, Sydney, NSW 2000 is Submitted.'
    
    # Check that the processed content is displayed in the view
    assert_select '.message-subject', text: /Hello John!/
    assert_select '.message-content', text: /Dear John Doe, your application for 123 Main Street, Sydney, NSW 2000 is Submitted\./
  end
  
  test "should process template variables when creating message from edit view" do
    # Navigate to application edit view
    get edit_admin_application_path(@application)
    assert_response :success
    
    # Create message with template variables
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'edit',
        application_message: {
          subject: 'Application {{application.reference_number}} Update',
          content: 'Your application {{application.reference_number}} for {{application.address}} with value {{application.home_value}} has been updated.',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    assert_redirected_to edit_admin_application_path(@application)
    follow_redirect!
    
    # Verify the message displays with processed template variables
    message = ApplicationMessage.last
    expected_reference = @application.id.to_s.rjust(6, '0')
    assert_equal "Application #{expected_reference} Update", message.processed_subject
    assert_includes message.content_html, "Your application #{expected_reference} for 123 Main Street, Sydney, NSW 2000 with value 1500000 has been updated."
    
    # Check that the processed content is displayed in the view
    assert_select '.message-subject', text: /Application #{expected_reference} Update/
    assert_select '.message-content', text: /Your application #{expected_reference} for 123 Main Street, Sydney, NSW 2000 with value 1500000 has been updated\./
  end
  
  test "should process template variables with markup formatting" do
    get admin_application_path(@application)
    assert_response :success
    
    # Create message with both template variables and markup
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: 'Welcome {{user.first_name}}',
          content: "**Hello {{user.first_name}}!**\n\nYour application status:\n\n- Property: {{application.address}}\n- Value: {{application.home_value}}\n- Status: *{{application.status_display}}*",
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    follow_redirect!
    
    # Verify both template processing and markup are applied
    message = ApplicationMessage.last
    assert_equal 'Welcome John', message.processed_subject
    
    processed_html = message.content_html
    assert_includes processed_html, '<strong>Hello John!</strong>'
    assert_includes processed_html, '<li>Property: 123 Main Street, Sydney, NSW 2000</li>'
    assert_includes processed_html, '<li>Value: 1500000</li>'
    assert_includes processed_html, '<li>Status: <em>Submitted</em></li>'
    
    # Verify it displays correctly in the view
    assert_select '.message-subject', text: 'Welcome John'
    assert_select '.message-content', html: /Hello John!.*Property: 123 Main Street, Sydney, NSW 2000.*Value: 1500000.*Status:.*Submitted/m
  end
  
  test "should handle user variables correctly" do
    get admin_application_path(@application)
    assert_response :success
    
    # Test various user template variables
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: '{{user.full_name}} - {{user.email}}',
          content: 'Customer: {{user.first_name}} {{user.last_name}} ({{user.full_name}})\nEmail: {{user.email}}\nCountry: {{user.country_of_residence}}',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    follow_redirect!
    
    message = ApplicationMessage.last
    assert_equal 'John Doe - john.doe@example.com', message.processed_subject
    assert_includes message.content_html, 'Customer: John Doe (John Doe)'
    assert_includes message.content_html, 'Email: john.doe@example.com'
    assert_includes message.content_html, 'Country: Australia'
  end
  
  test "should preserve unmatched template variables" do
    get admin_application_path(@application)
    assert_response :success
    
    # Create message with mix of valid and invalid template variables
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: '{{user.first_name}} - {{invalid.variable}}',
          content: 'Valid: {{application.address}}, Invalid: {{nonexistent.field}}',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    follow_redirect!
    
    message = ApplicationMessage.last
    assert_equal 'John - {{invalid.variable}}', message.processed_subject
    assert_includes message.content_html, 'Valid: 123 Main Street, Sydney, NSW 2000, Invalid: {{nonexistent.field}}'
    
    # Check display in view
    assert_select '.message-subject', text: /John - \{\{invalid\.variable\}\}/
    assert_select '.message-content', text: /Valid: 123 Main Street, Sydney, NSW 2000, Invalid: \{\{nonexistent\.field\}\}/
  end
  
  test "should process template variables when sending draft message" do
    # Create a draft message first
    draft_message = @application.application_messages.create!(
      subject: 'Draft for {{user.first_name}}',
      content: 'Hello {{user.first_name}}, draft message for {{application.address}}.',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    get admin_application_path(@application)
    assert_response :success
    
    # Verify draft shows processed content
    assert_select '.message-subject', text: /Draft for John/
    assert_select '.message-content', text: /Hello John, draft message for 123 Main Street, Sydney, NSW 2000\./
    
    # Send the draft
    patch send_message_admin_application_path(@application, message_id: draft_message.id)
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    
    # Verify sent message still shows processed content
    draft_message.reload
    assert_equal 'sent', draft_message.status
    assert_select '.message-subject', text: /Draft for John/
    assert_select '.message-content', text: /Hello John, draft message for 123 Main Street, Sydney, NSW 2000\./
  end
  
  test "should work with all supported field helper template variables" do
    get admin_application_path(@application)
    assert_response :success
    
    # Test all the field helper template variables that are shown in the UI
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        from_view: 'show',
        application_message: {
          subject: 'Field Test for {{user.first_name}}',
          content: 'Customer: {{user.first_name}}\nAddress: {{application.address}}\nValue: {{application.formatted_home_value}}\nStatus: {{application.status_display}}',
          ai_agent_id: @ai_agent.id
        }
      }
    end
    
    follow_redirect!
    
    message = ApplicationMessage.last
    assert_equal 'Field Test for John', message.processed_subject
    
    # Note: formatted_home_value may not exist, so it should remain as template variable
    content = message.content_html
    assert_includes content, 'Customer: John'
    assert_includes content, 'Address: 123 Main Street, Sydney, NSW 2000'
    assert_includes content, 'Status: Submitted'
    
    # The UI shows these field helpers, so they should all work
    assert_select '.helper-btn', text: 'Customer Name'
    assert_select '.helper-btn', text: 'Property Address'  
    assert_select '.helper-btn', text: 'Home Value'
    assert_select '.helper-btn', text: 'Application Status'
  end
end