require "test_helper"

class Console::SupportTicketsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @ticket = support_tickets(:open_ticket)
  end

  test "index shows queue stats and filters" do
    get console_support_tickets_path
    assert_response :success
    assert_select ".console-stat-label", text: "Open"
    assert_select "td a", text: @ticket.ticket_number

    get console_support_tickets_path(status: "resolved")
    assert_select "td a", text: support_tickets(:resolved_ticket).ticket_number
    assert_select "td a", { text: @ticket.ticket_number, count: 0 }
  end

  test "show renders conversation and reply form prefilled with AI draft" do
    @ticket.update_column(:ai_draft_reply, "Draft answer here")
    get console_support_ticket_path(@ticket)

    assert_response :success
    assert_select ".console-message", minimum: 1
    assert_select "textarea#support_ticket_message_body_text", text: /Draft answer here/
  end

  test "reply sends email from the signed-in admin and flips status" do
    assert_difference -> { @ticket.messages.count }, 1 do
      assert_enqueued_emails 1 do
        post reply_console_support_ticket_path(@ticket),
             params: { support_ticket_message: { body_text: "We are reviewing it today." } }
      end
    end

    message = @ticket.messages.order(:created_at).last
    assert_equal "agent", message.sender_type
    assert_equal users(:admin_user).email, message.sender_email
    assert_equal "waiting_on_customer", @ticket.reload.status
  end

  test "update sets resolved timestamp once" do
    patch console_support_ticket_path(@ticket), params: { support_ticket: { status: "resolved", priority: @ticket.priority, category: @ticket.category } }
    assert_not_nil @ticket.reload.resolved_at
  end

  test "close stamps closed_at" do
    post close_console_support_ticket_path(@ticket)
    assert_equal "closed", @ticket.reload.status
    assert_not_nil @ticket.closed_at
  end

  test "lender admin only sees their customers' tickets" do
    sign_in users(:lender_admin_user)
    get console_support_tickets_path
    assert_response :success
    assert_select "td a", { text: @ticket.ticket_number, count: 0 }

    get console_support_ticket_path(@ticket)
    assert_response :not_found
  end
end
