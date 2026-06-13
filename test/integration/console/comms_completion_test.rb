require "test_helper"

class Console::CommsCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @ticket = support_tickets(:open_ticket)
  end

  # --- Support ticket AI fields + SLA/age ------------------------------------------

  test "ticket page surfaces AI suggested category and confidence" do
    @ticket.update_columns(ai_draft_reply: "Thanks for reaching out…",
                           ai_suggested_category: "application", ai_confidence_score: 0.87)

    get console_support_ticket_path(@ticket)
    assert_match "Suggested category", response.body
    assert_match "application", response.body
    assert_match "87%", response.body
  end

  test "ticket page shows age and flags ones past the response target" do
    @ticket.update_columns(status: "open", created_at: 6.days.ago)

    get console_support_ticket_path(@ticket)
    assert_select ".console-dl-term", text: "Age"
    assert_match "past the 3-day response target", response.body
  end

  test "reply form accepts attachments and they persist" do
    file = Rack::Test::UploadedFile.new(StringIO.new("hello"), "text/plain", original_filename: "note.txt")

    assert_difference -> { @ticket.messages.count }, 1 do
      post reply_console_support_ticket_path(@ticket), params: {
        support_ticket_message: { body_text: "Here is the document.", attachments: [ file ] }
      }
    end
    assert @ticket.messages.order(:created_at).last.attachments.attached?
  end

  # --- Service desk avg response time ----------------------------------------------

  test "service desk surfaces the average response time KPI" do
    get console_service_desk_path
    assert_select ".console-stat-label", text: "Avg response (30d)"
  end

  test "presenter computes average response time from borrower/lender gaps" do
    app = Application.first!
    BorrowerMessage.create!(application: app, user: app.user, sender_type: "borrower", message: "Hello?", created_at: 3.hours.ago)
    BorrowerMessage.create!(application: app, user: app.user, sender_type: "lender", message: "Hi!", created_at: 1.hour.ago)

    avg = Console::ServiceDeskPresenter.new.avg_response_time_hours
    assert_operator avg, :>, 0
  end

  # --- Chat conversation subject ---------------------------------------------------

  test "conversation page shows its subject" do
    conversation = chat_conversations(:support_conversation)
    get console_chat_conversation_path(conversation)
    assert_response :success
    assert_select ".console-dl-term", text: "Subject"
    assert_match conversation.subject, response.body
  end
end
