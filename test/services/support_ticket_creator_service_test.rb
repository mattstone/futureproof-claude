require "test_helper"

class SupportTicketCreatorServiceTest < ActiveSupport::TestCase
  setup do
    @service = SupportTicketCreatorService.new
  end

  test "creates new ticket from email" do
    email_data = {
      message_id: "test-msg-#{SecureRandom.hex(4)}",
      subject: "How does the EPM work?",
      sender_email: "newperson@example.com",
      sender_name: "New Person",
      body_text: "I'd like to learn about the EPM.",
      body_html: "<p>I'd like to learn about the EPM.</p>",
      received_at: Time.current.iso8601,
      conversation_id: "conv-001",
      has_attachments: false
    }

    assert_difference "SupportTicket.count", 1 do
      assert_difference "SupportTicketMessage.count", 1 do
        @service.process_email(email_data)
      end
    end

    ticket = SupportTicket.last
    assert_equal "How does the EPM work?", ticket.subject
    assert_equal "newperson@example.com", ticket.sender_email
    assert_equal "New Person", ticket.sender_name
    assert_nil ticket.user
    assert_equal "New Contact", ticket.contact_type
    assert_equal "open", ticket.status
    assert_equal "general", ticket.category
  end

  test "matches existing customer by email" do
    user = users(:regular_user)

    email_data = {
      message_id: "test-msg-#{SecureRandom.hex(4)}",
      subject: "Question about my application",
      sender_email: user.email,
      sender_name: "Regular User",
      body_text: "What's the status of my application?",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-002",
      has_attachments: false
    }

    @service.process_email(email_data)

    ticket = SupportTicket.last
    assert_equal user, ticket.user
    assert_equal "Customer", ticket.contact_type
  end

  test "adds reply to existing ticket when subject contains ticket number" do
    # Create an existing ticket
    ticket = SupportTicket.create!(
      ticket_number: "TEMP-test",
      subject: "Original question",
      sender_email: "customer@example.com",
      sender_name: "Customer",
      status: "waiting_on_customer"
    )
    ticket.messages.create!(sender_type: "customer", body_text: "Original message", sender_email: "customer@example.com")

    # Simulate a reply with ticket number in subject
    email_data = {
      message_id: "test-reply-#{SecureRandom.hex(4)}",
      subject: "Re: [#{ticket.ticket_number}] Original question",
      sender_email: "customer@example.com",
      sender_name: "Customer",
      body_text: "Thanks for the info, I have a follow-up question.",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-003",
      has_attachments: false
    }

    assert_no_difference "SupportTicket.count" do
      assert_difference "SupportTicketMessage.count", 1 do
        @service.process_email(email_data)
      end
    end

    ticket.reload
    assert_equal "open", ticket.status # reopened from waiting_on_customer
    assert_equal 2, ticket.messages.count
  end

  test "skips duplicate emails by message_id" do
    message_id = "test-dedup-#{SecureRandom.hex(4)}"

    email_data = {
      message_id: message_id,
      subject: "First time",
      sender_email: "person@example.com",
      sender_name: "Person",
      body_text: "Hello",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-004",
      has_attachments: false
    }

    @service.process_email(email_data)

    assert_no_difference "SupportTicket.count" do
      @service.process_email(email_data)
    end
  end

  test "detects urgent priority from body" do
    email_data = {
      message_id: "test-urgent-#{SecureRandom.hex(4)}",
      subject: "Need help ASAP",
      sender_email: "urgent@example.com",
      sender_name: "Urgent Person",
      body_text: "This is urgent, I need help immediately!",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-005",
      has_attachments: false
    }

    @service.process_email(email_data)
    assert_equal "urgent", SupportTicket.last.priority
  end

  test "detects payment category" do
    email_data = {
      message_id: "test-payment-#{SecureRandom.hex(4)}",
      subject: "Missing payment",
      sender_email: "pay@example.com",
      sender_name: "Pay Person",
      body_text: "My annuity payment has not been received this month.",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-006",
      has_attachments: false
    }

    @service.process_email(email_data)
    assert_equal "payment", SupportTicket.last.category
  end

  test "detects complaint category" do
    email_data = {
      message_id: "test-complaint-#{SecureRandom.hex(4)}",
      subject: "Formal complaint",
      sender_email: "complain@example.com",
      sender_name: "Complainer",
      body_text: "I wish to make a formal complaint about the service.",
      body_html: nil,
      received_at: Time.current.iso8601,
      conversation_id: "conv-007",
      has_attachments: false
    }

    @service.process_email(email_data)
    assert_equal "complaint", SupportTicket.last.category
  end
end
