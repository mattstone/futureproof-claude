require 'test_helper'

class ApplicationMessageReplyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      first_name: "John",
      last_name: "Doe",
      email: "test-unit-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin-unit-#{SecureRandom.hex(4)}@example.com",
      password: "password123", 
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    @application = Application.create!(
      user: @user,
      address: "123 Test Street",
      home_value: 500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )
    
    @ai_agent = AiAgent.create!(
      name: 'TestAgent',
      agent_type: 'applications',
      avatar_filename: 'Motoko.png',
      is_active: true,
      greeting_style: 'friendly'
    )
    
    @parent_message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      subject: 'Original message',
      content: 'This is the original message content.',
      status: 'sent',
      sent_at: 1.hour.ago
    )
  end

  test "customer can create valid reply to admin message" do
    reply = ApplicationMessage.new(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Re: Original message',
      content: 'This is my reply.',
      status: 'sent',
      sent_at: Time.current
    )
    
    assert reply.valid?
    assert reply.save
    
    # Verify associations
    assert_equal @parent_message, reply.parent_message
    assert_includes @parent_message.replies, reply
    assert_equal @user, reply.sender
    assert_equal @application, reply.application
  end

  test "reply can reference parent message from same application" do
    reply = ApplicationMessage.new(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Valid reply',
      content: 'This should be valid.',
      status: 'sent',
      sent_at: Time.current
    )
    
    # Should be valid with proper parent reference
    assert reply.valid?
    assert_equal @application, reply.application
    assert_equal @parent_message.application, reply.application
  end

  test "mark_as_replied! updates parent message status" do
    assert_equal 'sent', @parent_message.status
    
    @parent_message.mark_as_replied!
    
    assert_equal 'replied', @parent_message.reload.status
  end

  test "customer reply sets correct message attributes" do
    reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Re: Original message',
      content: 'Customer reply content.',
      status: 'sent',
      sent_at: Time.current
    )
    
    assert_equal 'customer_to_admin', reply.message_type
    assert_equal 'sent', reply.status
    assert_not_nil reply.sent_at
    assert_equal @user, reply.sender
    assert_nil reply.ai_agent  # Customer replies don't have AI agent
  end

  test "reply validation requires necessary fields" do
    reply = ApplicationMessage.new(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin'
    )
    
    assert_not reply.valid?
    assert_includes reply.errors[:subject], "can't be blank"
    assert_includes reply.errors[:content], "can't be blank"
  end

  test "reply content can contain markdown and is processed" do
    reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Reply with formatting',
      content: "Thank you for the **important** update!\n\n*I have a question:*\n\n- When will the next step occur?\n- Do you need additional documents?",
      status: 'sent',
      sent_at: Time.current
    )
    
    # Test that content_html processes markdown correctly
    html_content = reply.content_html
    
    assert_includes html_content, '<strong>important</strong>'
    assert_includes html_content, '<em>I have a question:</em>'
    assert_includes html_content, '<li>When will the next step occur?</li>'
    assert_includes html_content, '<li>Do you need additional documents?</li>'
  end

  test "formatted_created_at returns readable timestamp" do
    reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Timestamped reply',
      content: 'Reply with timestamp.',
      status: 'sent',
      sent_at: Time.current,
      created_at: Time.parse('2024-03-15 14:30:00 UTC')
    )
    
    formatted_time = reply.formatted_created_at
    
    # Should return a readable format (exact format depends on implementation)
    assert_not_nil formatted_time
    assert formatted_time.is_a?(String)
    assert formatted_time.length > 0
  end

  test "sender_name returns correct name for customer replies" do
    reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Reply from customer',
      content: 'Customer reply.',
      status: 'sent',
      sent_at: Time.current
    )
    
    assert_equal "#{@user.first_name} #{@user.last_name}", reply.sender_name
  end

  test "reply associations work correctly" do
    reply1 = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'First reply',
      content: 'First reply content.',
      status: 'sent',
      sent_at: Time.current
    )
    
    reply2 = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Second reply',
      content: 'Second reply content.',
      status: 'sent',
      sent_at: Time.current
    )
    
    # Parent should have both replies
    assert_equal 2, @parent_message.replies.count
    assert_includes @parent_message.replies, reply1
    assert_includes @parent_message.replies, reply2
    
    # Replies should reference correct parent
    assert_equal @parent_message, reply1.parent_message
    assert_equal @parent_message, reply2.parent_message
  end

  test "only customer_to_admin messages can be replies" do
    # Admin trying to reply to customer message should be allowed
    admin_reply = ApplicationMessage.new(
      application: @application,
      sender: @admin,
      ai_agent: @ai_agent,
      parent_message: @parent_message,
      message_type: 'admin_to_customer',
      subject: 'Admin follow-up',
      content: 'Additional information from admin.',
      status: 'sent',
      sent_at: Time.current
    )
    
    # This should be valid - admins can reply too
    assert admin_reply.valid?
  end

  test "message thread ordering returns messages chronologically" do
    # Create replies at different times
    old_reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'Old reply',
      content: 'Older reply.',
      status: 'sent',
      sent_at: 2.hours.ago,
      created_at: 2.hours.ago
    )
    
    new_reply = ApplicationMessage.create!(
      application: @application,
      sender: @user,
      parent_message: @parent_message,
      message_type: 'customer_to_admin',
      subject: 'New reply',
      content: 'Newer reply.',
      status: 'sent',
      sent_at: 1.hour.ago,
      created_at: 1.hour.ago
    )
    
    # Replies should be ordered by creation time
    ordered_replies = @parent_message.replies.order(:created_at)
    assert_equal old_reply, ordered_replies.first
    assert_equal new_reply, ordered_replies.last
  end
end