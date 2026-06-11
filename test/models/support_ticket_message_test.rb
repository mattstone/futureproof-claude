require "test_helper"

class SupportTicketMessageTest < ActiveSupport::TestCase
  setup do
    @ticket = SupportTicket.create!(
      ticket_number: "TEMP-#{SecureRandom.hex(4)}",
      subject: "Test ticket",
      sender_email: "test@example.com"
    )
  end

  test "creates message on ticket" do
    message = @ticket.messages.create!(
      sender_type: "customer",
      sender_email: "test@example.com",
      sender_name: "Test User",
      body_text: "Hello, I need help"
    )

    assert message.persisted?
    assert message.from_customer?
    assert_not message.from_agent?
  end

  test "validates sender_type" do
    message = @ticket.messages.build(body_text: "test", sender_type: "invalid")
    assert_not message.valid?
    assert_includes message.errors[:sender_type], "is not included in the list"
  end

  test "validates body_text presence" do
    message = @ticket.messages.build(sender_type: "customer", body_text: nil)
    assert_not message.valid?
    assert_includes message.errors[:body_text], "can't be blank"
  end

  test "visible scope excludes ai_draft" do
    @ticket.messages.create!(sender_type: "customer", body_text: "Help", sender_email: "test@example.com")
    @ticket.messages.create!(sender_type: "ai_draft", body_text: "Draft reply")

    assert_equal 1, @ticket.messages.visible.count
    assert_equal 2, @ticket.messages.count
  end

  test "touching ticket on message create" do
    original_updated = @ticket.updated_at
    sleep 0.1

    @ticket.messages.create!(sender_type: "customer", body_text: "New message", sender_email: "test@example.com")
    @ticket.reload

    assert @ticket.updated_at > original_updated
  end
end
