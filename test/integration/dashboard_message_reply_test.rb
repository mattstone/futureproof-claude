require 'test_helper'

class DashboardMessageReplyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(confirmed_at: 1.day.ago)
    
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
      email: "admin-test@example.com",
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
      subject: 'Welcome to your application',
      content: 'Thank you for your application. We are reviewing it now.',
      status: 'sent',
      sent_at: 2.hours.ago
    )
    
    sign_in @user
  end

  test "dashboard shows message reply form with correct structure" do
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Verify reply form exists but is hidden
    assert_select "#reply-form-#{@message.id}[style*='display: none']"
    assert_select "form[action*='#{reply_to_message_application_path(@application)}']"
    assert_select "input[name*='parent_message_id'][value='#{@message.id}']", visible: false
    assert_select "input[name*='subject'][required]"
    assert_select "textarea[name*='content'][required]"
    assert_select "input[type='submit'][value='Send Reply']"
    
    # Verify no markup help is shown (as per user requirements)
    assert_select '.form-hint', { text: /markup/i, count: 0 }
  end

  test "submitting reply via HTML request (fallback) creates message and redirects" do
    assert_difference 'ApplicationMessage.count', 1 do
      post reply_to_message_application_path(@application), 
           params: {
             application_message: {
               subject: "Re: #{@message.subject}",
               content: "Thank you for the update. When can I expect next steps?"
             },
             parent_message_id: @message.id
           },
           headers: { 'Accept' => 'text/html' }
    end
    
    assert_redirected_to messages_application_path(@application)
    assert_equal 'Your reply has been sent!', flash[:notice]
    
    reply_message = ApplicationMessage.last
    assert_equal @user, reply_message.sender
    assert_equal 'customer_to_admin', reply_message.message_type
    assert_equal 'sent', reply_message.status
    assert_equal @message, reply_message.parent_message
    assert_not_nil reply_message.sent_at
  end

  test "submitting reply via Turbo request returns success stream response" do
    assert_difference 'ApplicationMessage.count', 1 do
      post reply_to_message_application_path(@application), 
           params: {
             application_message: {
               subject: "Re: #{@message.subject}",
               content: "Thank you for the information."
             },
             parent_message_id: @message.id
           },
           headers: { 
             'Accept' => 'text/vnd.turbo-stream.html',
             'Turbo-Frame' => 'true' 
           }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify turbo stream response contains success elements
    assert_match /turbo-stream.*update.*reply-form-#{@message.id}/, response.body
    assert_match /reply-success-message/, response.body
    assert_match /Your reply has been sent successfully!/, response.body
  end

  test "invalid reply submission via Turbo returns error stream response" do
    assert_no_difference 'ApplicationMessage.count' do
      post reply_to_message_application_path(@application),
           params: {
             application_message: {
               subject: "",  # Empty subject should fail validation
               content: ""   # Empty content should fail validation
             },
             parent_message_id: @message.id
           },
           headers: { 
             'Accept' => 'text/vnd.turbo-stream.html',
             'Turbo-Frame' => 'true'
           }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify turbo stream response contains error form
    assert_match /turbo-stream.*update.*reply-form-#{@message.id}/, response.body
    assert_match /form-errors/, response.body
  end

  test "parent message is marked as replied when customer replies" do
    assert_equal 'sent', @message.status
    
    post reply_to_message_application_path(@application),
         params: {
           application_message: {
             subject: "Re: #{@message.subject}",
             content: "Thanks for the message!"
           },
           parent_message_id: @message.id
         }
    
    # Parent message should be marked as replied
    @message.reload
    assert_equal 'replied', @message.status
  end

  test "reply form validates required fields" do
    # Test empty subject
    assert_no_difference 'ApplicationMessage.count' do
      post reply_to_message_application_path(@application),
           params: {
             application_message: {
               subject: "",
               content: "Valid content"
             },
             parent_message_id: @message.id
           }
    end
    
    assert_response :unprocessable_entity
    
    # Test empty content
    assert_no_difference 'ApplicationMessage.count' do
      post reply_to_message_application_path(@application),
           params: {
             application_message: {
               subject: "Valid subject",
               content: ""
             },
             parent_message_id: @message.id
           }
    end
    
    assert_response :unprocessable_entity
  end

  test "dashboard shows unread message count in sidebar badge" do
    # Create additional unread messages
    2.times do |i|
      ApplicationMessage.create!(
        application: @application,
        sender: @admin,
        ai_agent: @ai_agent,
        message_type: 'admin_to_customer',
        subject: "Additional message #{i + 1}",
        content: "More content",
        status: 'sent',
        sent_at: 1.hour.ago
      )
    end
    
    get dashboard_path
    
    assert_response :success
    
    # Should show unread badge with count (3 total unread messages)
    assert_select '.unread-badge', text: '3'
    assert_select "a[href*='applications'] .unread-badge"
  end

  test "dashboard hides unread message badge when count is zero" do
    # Mark existing message as read
    @message.update!(status: 'read', read_at: Time.current)
    
    get dashboard_path
    
    assert_response :success
    
    # Should not show unread badge
    assert_select '.unread-badge', count: 0
  end

  test "reply button and form are properly connected with JavaScript functions" do
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Verify reply button with correct onclick handler
    assert_select "button[onclick*='showReplyForm(#{@message.id})']", text: /Reply/
    
    # Verify JavaScript functions are included
    assert_match /function showReplyForm/, response.body
    assert_match /function hideReplyForm/, response.body
    assert_match /function toggleApplicationMessages/, response.body
  end

  test "message thread displays AI agent information correctly" do
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Should show AI agent name and badge  
    assert_select '.sender-name strong', text: /Motoko/
    assert_select '.ai-badge', text: 'AI Assistant'
    assert_select '.sender-role', text: /Application Processing Specialist/
    
    # Should show agent avatar or fallback
    assert_select '.agent-avatar img, .default-avatar'
  end

  test "message status is displayed correctly" do
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Should show message status
    assert_select '.message-status.status-sent', text: /Sent/
    
    # Update message to read status
    @message.update!(status: 'read')
    get dashboard_path(section: 'applications')
    
    assert_select '.message-status.status-read', text: /Read/
  end

  test "message content is properly formatted and processed" do
    # Update message with template variables and markdown
    @message.update!(
      content: "Hello **{{user.first_name}}**! Your application for {{application.address}} is being reviewed.\n\n*Next steps:*\n- Review documents\n- Wait for approval"
    )
    
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Should process template variables
    assert_select '.message-content', text: /Hello.*#{@user.first_name}!/
    assert_select '.message-content', text: /#{@application.address}/
    
    # Should render markdown as HTML
    assert_select '.message-content strong', text: @user.first_name
    assert_select '.message-content em', text: 'Next steps:'
    assert_select '.message-content li', text: 'Review documents'
  end

  test "multiple applications with messages display correctly" do
    # Clear any existing applications for this user to avoid interference
    @user.applications.destroy_all
    
    # Create first application 
    first_app = Application.create!(
      user: @user,
      address: "123 First Street, Portland, OR",
      home_value: 800000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )
    
    # Create second application 
    second_app = Application.create!(
      user: @user,
      address: "456 Second Street, Seattle, WA",
      home_value: 600000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 67
    )
    
    ApplicationMessage.create!(
      application: first_app,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'First application received',
      content: 'Your first application is being reviewed.',
      status: 'sent',
      sent_at: 2.hours.ago
    )
    
    ApplicationMessage.create!(
      application: second_app,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Second application received',
      content: 'Your second application is also being reviewed.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
    
    get dashboard_path(section: 'applications')
    
    assert_response :success
    
    # Should show both applications
    assert_select '.application-card.enhanced', count: 2
    assert_select "#application-#{first_app.id}"
    assert_select "#application-#{second_app.id}"
    
    # Each should have their own message sections
    assert_select "#messages-#{first_app.id}"
    assert_select "#messages-#{second_app.id}"
  end

  test "reply creates proper message thread hierarchy" do
    # Post initial reply
    post reply_to_message_application_path(@application),
         params: {
           application_message: {
             subject: "Re: #{@message.subject}",
             content: "Initial reply"
           },
           parent_message_id: @message.id
         }
    
    reply1 = ApplicationMessage.last
    
    # Post second reply to same parent
    post reply_to_message_application_path(@application),
         params: {
           application_message: {
             subject: "Re: #{@message.subject}",
             content: "Follow up reply"
           },
           parent_message_id: @message.id
         }
    
    reply2 = ApplicationMessage.last
    
    # Both replies should have correct parent
    assert_equal @message, reply1.parent_message
    assert_equal @message, reply2.parent_message
    
    # Parent should have both replies
    assert_includes @message.replies, reply1
    assert_includes @message.replies, reply2
    assert_equal 2, @message.replies.count
  end

  test "user can successfully reply to their own application messages" do
    # Verify user can reply to their own applications (positive test)
    assert_difference 'ApplicationMessage.count', 1 do
      post reply_to_message_application_path(@application),
           params: {
             application_message: {
               subject: "Re: #{@message.subject}",
               content: "This should work since it's my application"
             },
             parent_message_id: @message.id
           }
    end
    
    # Should redirect successfully (not raise an exception)
    assert_redirected_to messages_application_path(@application)
    
    # Verify reply was created correctly
    reply = ApplicationMessage.last
    assert_equal @user, reply.sender
    assert_equal @application, reply.application
    assert_equal @message, reply.parent_message
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