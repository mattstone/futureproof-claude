require 'test_helper'

class Admin::HotwireMessagingTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts, :ai_agents
  
  def setup
    # Clean up any existing messages between tests
    ApplicationMessage.destroy_all
    ContractMessage.destroy_all
    
    @admin = users(:admin_user)
    @customer = users(:john)
    @application = applications(:submitted_application)
    @contract = contracts(:basic_contract)
    @ai_agent = ai_agents(:customer_success_manager)
    
    # Ensure the application belongs to the customer
    @application.update!(user: @customer)
    
    # Ensure the contract's application belongs to the customer
    @contract.application.update!(user: @customer)
  end

  test "admin sends message via Turbo Stream and updates message count" do
    admin_sign_in
    
    # Navigate to application show page
    get admin_application_path(@application)
    assert_response :success
    
    # Verify initial message count is 0
    assert_select '#message-count .message-count', text: '0'
    
    # Send a message via Turbo Stream
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        application_message: {
          subject: "Test Hotwire Message",
          content: "This message should update the count and be inserted at the top",
          ai_agent_id: @ai_agent.id
        },
        send_now: true,
        from_view: 'show'
      }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_match 'text/vnd.turbo-stream.html', response.content_type
    
    # Verify the response contains Turbo Stream updates
    assert_match 'turbo-stream action="update" target="message-form"', response.body
    assert_match 'turbo-stream action="prepend" target="message-threads"', response.body
    assert_match 'turbo-stream action="update" target="message-count"', response.body
    assert_match 'turbo-stream action="update" target="flash-messages"', response.body
    
    # Verify the message was created correctly
    message = ApplicationMessage.last
    assert_equal @application, message.application
    assert_equal @admin, message.sender
    assert_equal 'admin_to_customer', message.message_type
    assert_equal 'sent', message.status
    assert_equal @ai_agent, message.ai_agent
    assert_equal "Test Hotwire Message", message.subject
    
    # Verify the response contains the new message
    assert_match "Test Hotwire Message", response.body
    assert_match message.content, response.body
    
    # Verify the message count was updated to 1
    assert_match '<span class="message-count">1</span>', response.body
    
    # Verify success flash message
    assert_match 'Message sent successfully!', response.body
    assert_match 'alert-success', response.body
  end

  test "admin saves draft message via Turbo Stream and updates draft count" do
    admin_sign_in
    
    # Navigate to application show page
    get admin_application_path(@application)
    assert_response :success
    
    # Send a draft message via Turbo Stream
    assert_difference 'ApplicationMessage.count', 1 do
      post create_message_admin_application_path(@application), params: {
        application_message: {
          subject: "Draft Message via Hotwire",
          content: "This is a draft message that should update the draft count",
          ai_agent_id: @ai_agent.id
        },
        save_draft: true,
        from_view: 'show'
      }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_match 'text/vnd.turbo-stream.html', response.content_type
    
    # Verify the response contains Turbo Stream updates
    assert_match 'turbo-stream action="update" target="message-form"', response.body
    assert_match 'turbo-stream action="prepend" target="message-threads"', response.body
    assert_match 'turbo-stream action="update" target="draft-count"', response.body
    assert_match 'turbo-stream action="update" target="flash-messages"', response.body
    
    # Verify the draft message was created correctly
    message = ApplicationMessage.last
    assert_equal 'draft', message.status
    assert_nil message.sent_at
    
    # Verify the draft count was updated to 1
    assert_match '<span class="draft-count">1</span>', response.body
    
    # Verify the message appears with a send button
    assert_match "Draft Message via Hotwire", response.body
    assert_match 'Send Message', response.body
    
    # Verify success flash message
    assert_match 'Message saved as draft!', response.body
  end

  test "admin sends draft message via Turbo Stream and updates both counts" do
    admin_sign_in
    
    # First create a draft message
    draft_message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      message_type: 'admin_to_customer',
      subject: "Draft to be sent",
      content: "This draft will be sent via Hotwire",
      status: 'draft',
      ai_agent: @ai_agent
    )
    
    # Send the draft message via Turbo Stream
    assert_no_difference 'ApplicationMessage.count' do
      patch send_message_admin_application_path(@application, message_id: draft_message.id),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_match 'text/vnd.turbo-stream.html', response.content_type
    
    # Verify the message was sent
    draft_message.reload
    assert_equal 'sent', draft_message.status
    assert_not_nil draft_message.sent_at
    
    # Verify Turbo Stream updates
    assert_match 'turbo-stream action="update" target="message-count"', response.body
    assert_match 'turbo-stream action="update" target="flash-messages"', response.body
    
    # Verify success flash message
    assert_match 'Message sent successfully!', response.body
  end

  test "message validation errors are handled via Turbo Stream" do
    admin_sign_in
    
    # Try to send a message with validation errors via Turbo Stream
    assert_no_difference 'ApplicationMessage.count' do
      post create_message_admin_application_path(@application), params: {
        application_message: {
          subject: "", # Empty subject should cause validation error
          content: "",  # Empty content should cause validation error
          ai_agent_id: @ai_agent.id
        },
        send_now: true,
        from_view: 'show'
      }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_match 'text/vnd.turbo-stream.html', response.content_type
    
    # Verify the response contains form with validation errors
    assert_match 'turbo-stream action="update" target="message-form"', response.body
    assert_match 'alert-danger', response.body
    assert_match "can&#39;t be blank", response.body
    
    # Verify form fields have error styling
    assert_match 'class="error"', response.body
    assert_match 'field-error', response.body
  end

  test "contract messaging works with Turbo Stream and updates contract message count" do
    admin_sign_in
    
    # Navigate to contract show page
    get admin_contract_path(@contract)
    assert_response :success
    
    # Verify initial message count is 0
    assert_select '#message-count .message-count', text: '0'
    
    # Send a contract message via Turbo Stream
    assert_difference 'ContractMessage.count', 1 do
      post create_message_admin_contract_path(@contract), params: {
        contract_message: {
          subject: "Contract Hotwire Message",
          content: "This contract message should update the count and be inserted at the top",
          ai_agent_id: @ai_agent.id
        },
        send_now: true,
        from_view: 'show'
      }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_match 'text/vnd.turbo-stream.html', response.content_type
    
    # Verify the response contains Turbo Stream updates
    assert_match 'turbo-stream action="update" target="message-form"', response.body
    assert_match 'turbo-stream action="prepend" target="message-threads"', response.body
    assert_match 'turbo-stream action="update" target="message-count"', response.body
    
    # Verify the contract message was created correctly
    message = ContractMessage.last
    assert_equal @contract, message.contract
    assert_equal @admin, message.sender
    assert_equal 'admin_to_customer', message.message_type
    assert_equal 'sent', message.status
    
    # Verify the message count was updated to 1
    assert_match '<span class="message-count">1</span>', response.body
    
    # Verify contract-specific content
    assert_match "Contract Hotwire Message", response.body
  end

  test "new messages are inserted at the top of message list" do
    admin_sign_in
    
    # Create an existing message
    existing_message = ApplicationMessage.create!(
      application: @application,
      sender: @admin,
      message_type: 'admin_to_customer',
      subject: "Existing Message",
      content: "This message was created first",
      status: 'sent',
      sent_at: 1.hour.ago,
      ai_agent: @ai_agent
    )
    
    # Navigate to application show page
    get admin_application_path(@application)
    assert_response :success
    
    # Send a new message via Turbo Stream
    post create_message_admin_application_path(@application), params: {
      application_message: {
        subject: "New Message",
        content: "This message should appear at the top",
        ai_agent_id: @ai_agent.id
      },
      send_now: true,
      from_view: 'show'
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify that the new message is prepended (added to the top)
    assert_match 'turbo-stream action="prepend" target="message-threads"', response.body
    
    # The new message should appear in the response with its content
    new_message = ApplicationMessage.last
    assert_match new_message.subject, response.body
    assert_match "This message should appear at the top", response.body
    
    # Verify both messages exist
    assert_equal 2, @application.application_messages.count
  end

  test "message form is cleared after successful send" do
    admin_sign_in
    
    # Send a message via Turbo Stream
    post create_message_admin_application_path(@application), params: {
      application_message: {
        subject: "Test Message",
        content: "This message form should be cleared after send",
        ai_agent_id: @ai_agent.id
      },
      send_now: true,
      from_view: 'show'
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify the form is replaced with a fresh empty form
    assert_match 'turbo-stream action="update" target="message-form"', response.body
    
    # The response should contain a fresh form without the previous values
    assert_match 'placeholder="Message subject..."', response.body
    assert_match 'placeholder="Type your message here..."', response.body
    
    # Should not contain the sent message content as values in the form inputs
    # (The content may appear in the message history, but not as form values)
    assert_no_match 'value="Test Message"', response.body
    # Check that the textarea is empty (between opening and closing tags)
    assert_match /<textarea[^>]*>\s*<\/textarea>/, response.body
  end

  test "flash messages are displayed and dismissible via Turbo Stream" do
    admin_sign_in
    
    # Send a message via Turbo Stream
    post create_message_admin_application_path(@application), params: {
      application_message: {
        subject: "Flash Test Message",
        content: "Testing flash message display",
        ai_agent_id: @ai_agent.id
      },
      send_now: true,
      from_view: 'show'
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify flash message structure
    assert_match 'turbo-stream action="update" target="flash-messages"', response.body
    assert_match 'alert alert-success alert-dismissible', response.body
    assert_match 'fas fa-check-circle', response.body
    assert_match 'Message sent successfully!', response.body
    assert_match 'btn-close', response.body
    assert_match 'onclick="this.parentElement.remove()"', response.body
  end

  test "error messages are displayed properly via Turbo Stream" do
    admin_sign_in
    
    # Simulate sending a message that would fail
    # We'll test this by triggering a validation error
    post create_message_admin_application_path(@application), params: {
      application_message: {
        subject: "",  # This will cause validation error
        content: "Content without subject",
        ai_agent_id: @ai_agent.id
      },
      send_now: true,
      from_view: 'show'
    }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify error message structure
    assert_match 'alert alert-danger', response.body
    assert_match "can&#39;t be blank", response.body
    
    # Verify the form retains the entered content for correction
    assert_match "Content without subject", response.body
  end

  test "multiple rapid messages maintain correct order and counts" do
    admin_sign_in
    
    # Send multiple messages rapidly
    3.times do |i|
      post create_message_admin_application_path(@application), params: {
        application_message: {
          subject: "Rapid Message #{i + 1}",
          content: "Content for message #{i + 1}",
          ai_agent_id: @ai_agent.id
        },
        send_now: true,
        from_view: 'show'
      }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      assert_response :success
    end
    
    # Verify all messages were created
    assert_equal 3, ApplicationMessage.count
    
    # The last response should show the correct count
    assert_match '<span class="message-count">3</span>', response.body
    
    # Verify messages are in the correct order (newest first)
    messages = ApplicationMessage.order(created_at: :desc)
    assert_equal "Rapid Message 3", messages.first.subject
    assert_equal "Rapid Message 1", messages.last.subject
  end

  private

  def admin_sign_in
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
  end
end