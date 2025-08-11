require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  def setup
    @user = create_user
    @admin = create_admin_user
    @application = create_application_for_user(@user)
    @agent = create_ai_agent
  end
  
  test "message_notification email generates correct secure link" do
    message = create_admin_message(@application, @admin, @agent, "Test Subject")
    
    email = ApplicationMailer.message_notification(message)
    
    assert_emails 0 # Don't actually send
    
    # Check email recipients and content
    assert_equal [@user.email], email.to
    assert_equal "Test Subject", email.subject
    assert_match @agent.display_name, email.from.first
    
    # Check that secure link is generated
    assert_match /messages_application_url/, email.body.encoded
    assert_match /token=/, email.body.encoded
  end
  
  test "message_notification email shows AI agent as sender" do
    message = create_admin_message(@application, @admin, @agent, "From AI Agent")
    
    email = ApplicationMailer.message_notification(message)
    
    # From field should show agent name
    assert_match @agent.display_name, email.from.first
    
    # Email body should contain agent information
    assert_match @agent.name, email.body.encoded
    assert_match @agent.role_description, email.body.encoded
  end
  
  test "message_notification email processes template variables" do
    content = "Hello {{user.first_name}}! Your application for {{application.address}} is ready."
    message = create_admin_message(@application, @admin, @agent, "Update", content)
    
    email = ApplicationMailer.message_notification(message)
    
    # Should process template variables in email body
    assert_match @user.first_name, email.body.encoded
    assert_match @application.address, email.body.encoded
    
    # Should not contain raw template variables
    assert_no_match /\{\{user\.first_name\}\}/, email.body.encoded
    assert_no_match /\{\{application\.address\}\}/, email.body.encoded
  end
  
  test "message_notification email includes View Application & Reply link" do
    message = create_admin_message(@application, @admin, @agent, "Test Message")
    
    email = ApplicationMailer.message_notification(message)
    
    # Should contain the action button
    assert_match "View Application & Reply", email.body.encoded
    
    # Link should point to messages_application_url with token
    assert_match %r{messages_application_url.*token=}, email.body.encoded
  end
  
  test "secure token contains correct payload" do
    message = create_admin_message(@application, @admin, @agent, "Test")
    
    # Call the mailer to generate the token
    email = ApplicationMailer.message_notification(message)
    
    # Extract token from email body (this is a bit hacky but works for testing)
    token_match = email.body.encoded.match(/token=([^"&]+)/)
    assert_not_nil token_match, "Token should be present in email"
    
    token = token_match[1]
    
    # Decrypt and verify token
    payload = SecureTokenEncryptor.decrypt_and_verify(token)
    
    assert_equal @application.id, payload['application_id']
    assert_equal @user.id, payload['user_id']
    assert payload['expires_at'] > Time.current.to_i
    assert payload['expires_at'] <= 24.hours.from_now.to_i
  end
  
  test "message_notification handles missing AI agent gracefully" do
    # Create message without AI agent
    message = @application.application_messages.create!(
      sender: @admin,
      subject: "Manual Message",
      content: "This is from admin directly",
      message_type: "admin_to_customer",
      status: "sent"
    )
    
    email = ApplicationMailer.message_notification(message)
    
    # Should still work and fall back to generic sender
    assert_equal [@user.email], email.to
    assert_equal "Manual Message", email.subject
    assert_match "Futureproof Financial Group", email.from.first
  end
  
  test "email includes proper styling and branding" do
    message = create_admin_message(@application, @admin, @agent, "Branded Email")
    
    email = ApplicationMailer.message_notification(message)
    
    body = email.body.encoded
    
    # Should include company branding
    assert_match "Futureproof Financial Group", body
    assert_match "Equity Preservation Mortgage", body
    
    # Should have professional styling  
    assert_match "background: linear-gradient", body
    assert_match "border-radius:", body
    
    # Should include agent avatar section when agent present
    assert_match @agent.name, body
    assert_match @agent.role_description, body
  end
  
  test "email content is properly formatted with HTML" do
    content = "Hello **John**!\n\n*Important:*\n\n- Item 1\n- Item 2"
    message = create_admin_message(@application, @admin, @agent, "Formatted", content)
    
    email = ApplicationMailer.message_notification(message)
    
    body = email.body.encoded
    
    # Should convert markup to HTML
    assert_match "<strong>John</strong>", body
    assert_match "<em>Important:</em>", body
    assert_match "<ul>", body
    assert_match "<li>Item 1</li>", body
    assert_match "<li>Item 2</li>", body
  end
  
  private
  
  def create_user
    User.create!(
      first_name: "Jane",
      last_name: "Smith", 
      email: "jane-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true
    )
  end
  
  def create_admin_user
    User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-#{SecureRandom.hex(4)}@test.com", 
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true
    )
  end
  
  def create_application_for_user(user)
    user.applications.create!(
      status: "submitted",
      home_value: 750000,
      address: "456 Email Test Ave, Test City",
      borrower_age: 60,
      ownership_status: "individual"
    )
  end
  
  def create_ai_agent
    AiAgent.create!(
      name: "EmailTestAgent",
      agent_type: "applications", 
      avatar_filename: "Motoko.png",
      is_active: true,
      greeting_style: "professional"
    )
  end
  
  def create_admin_message(application, admin, agent, subject, content = "Test email content")
    application.application_messages.create!(
      sender: admin,
      ai_agent: agent,
      subject: subject,
      content: content,
      message_type: "admin_to_customer",
      status: "sent",
      sent_at: Time.current
    )
  end
end