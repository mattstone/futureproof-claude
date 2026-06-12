require "test_helper"

class SupportTicketTest < ActiveSupport::TestCase
  test "creates ticket with auto-generated ticket number" do
    ticket = SupportTicket.create!(
      ticket_number: "TEMP-#{SecureRandom.hex(4)}",
      subject: "Test ticket",
      sender_email: "test@example.com",
      sender_name: "Test User"
    )

    # FP- + id left-padded to AT LEAST 5 digits (fixtures bump the id
    # sequence, so the generated id can exceed 5 digits)
    assert_match(/\AFP-\d{5,}\z/, ticket.ticket_number)
  end

  test "validates required fields" do
    ticket = SupportTicket.new
    assert_not ticket.valid?
    assert_includes ticket.errors[:subject], "can't be blank"
    assert_includes ticket.errors[:sender_email], "can't be blank"
  end

  test "validates status values" do
    ticket = SupportTicket.new(
      ticket_number: "TEMP-test",
      subject: "Test",
      sender_email: "test@example.com",
      status: "invalid"
    )
    assert_not ticket.valid?
    assert_includes ticket.errors[:status], "is not included in the list"
  end

  test "existing_customer returns true when user present" do
    user = users(:regular_user)
    ticket = SupportTicket.create!(
      ticket_number: "TEMP-#{SecureRandom.hex(4)}",
      subject: "Test",
      sender_email: user.email,
      user: user
    )
    assert ticket.existing_customer?
    assert_equal "Customer", ticket.contact_type
  end

  test "existing_customer returns false when no user" do
    ticket = SupportTicket.create!(
      ticket_number: "TEMP-#{SecureRandom.hex(4)}",
      subject: "Test",
      sender_email: "stranger@example.com"
    )
    assert_not ticket.existing_customer?
    assert_equal "New Contact", ticket.contact_type
  end

  test "search scope finds by subject" do
    SupportTicket.create!(ticket_number: "TEMP-s1", subject: "Payment issue help", sender_email: "a@test.com")
    SupportTicket.create!(ticket_number: "TEMP-s2", subject: "General question", sender_email: "b@test.com")

    results = SupportTicket.search("payment")
    assert_equal 1, results.count
    assert_equal "Payment issue help", results.first.subject
  end

  test "by_contact_type scope filters correctly" do
    user = users(:regular_user)
    SupportTicket.create!(ticket_number: "TEMP-c1", subject: "T1", sender_email: user.email, user: user)
    SupportTicket.create!(ticket_number: "TEMP-c2", subject: "T2", sender_email: "new@example.com")

    customers = SupportTicket.by_contact_type("customer")
    contacts = SupportTicket.by_contact_type("contact")

    assert customers.all?(&:existing_customer?)
    assert contacts.none?(&:existing_customer?)
  end
end
