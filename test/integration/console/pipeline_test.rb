require "test_helper"

class Console::PipelineTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    sign_in users(:admin_user)
  end

  # --- Index ---------------------------------------------------------------

  test "default pipeline hides accepted but filter and search reach them" do
    accepted = Application.find_by(status: :accepted)
    assert accepted, "needs an accepted application fixture"

    get console_applications_path
    assert_response :success
    assert_select "td", { text: "##{accepted.id}", count: 0 }

    get console_applications_path(status: "accepted")
    assert_select "td a", text: "##{accepted.id}"

    get console_applications_path(search: accepted.user.email)
    assert_select "td a", text: "##{accepted.id}"
  end

  test "numeric search matches the application id" do
    application = applications(:submitted_application)
    get console_applications_path(search: application.id.to_s)
    assert_response :success
    assert_select "td a", text: "##{application.id}"
  end

  # --- Show ----------------------------------------------------------------

  test "cockpit renders all tabs with decision panel for submitted" do
    application = applications(:submitted_application)
    get console_application_path(application)

    assert_response :success
    assert_select ".console-tab", count: 5
    assert_select ".console-card-title", text: "Decision"
    assert_select "form[action=?]", approve_console_application_path(application)
    assert_select "form[action=?]", reject_console_application_path(application)
    assert_select "#application-checklist"
  end

  test "viewing logs an audit version" do
    application = applications(:submitted_application)
    assert_difference -> { application.application_versions.where(action: "viewed").count } do
      get console_application_path(application)
    end
  end

  # --- Decisions -------------------------------------------------------------

  test "approve drives the full workflow and sets approved terms" do
    application = applications(:processing_application)
    application.application_checklists.each { |item| item.mark_completed!(users(:admin_user)) }

    post approve_console_application_path(application), params: {
      loan_amount: 500_000, interest_rate: 7.66, term_years: 30, lender_id: lenders(:futureproof).id
    }

    assert_redirected_to console_application_path(application)
    assert application.reload.status_accepted?
    assert_equal 500_000, application.approved_loan_amount.to_i
    assert_equal 30, application.approved_term_years
  end

  test "approve without a lender is refused" do
    application = applications(:processing_application)
    post approve_console_application_path(application), params: { loan_amount: 500_000, interest_rate: 7.66, term_years: 30 }
    assert_redirected_to console_application_path(application)
    assert_match(/needs a loan amount/, flash[:alert])
    assert_not application.reload.status_accepted?
  end

  test "reject requires a reason and records it" do
    application = applications(:submitted_application)

    post reject_console_application_path(application), params: { rejected_reason: "" }
    assert_match(/reason is required/, flash[:alert])
    assert_not application.reload.status_rejected?

    post reject_console_application_path(application), params: { rejected_reason: "Valuation too uncertain" }
    assert application.reload.status_rejected?
    assert_equal "Valuation too uncertain", application.rejected_reason
  end

  test "advance to processing creates the checklist" do
    application = applications(:submitted_application)
    patch advance_to_processing_console_application_path(application)

    assert application.reload.status_processing?
    assert application.application_checklists.any?, "expected the checklist to be created"
  end

  # --- Checklist ---------------------------------------------------------------

  test "checklist item toggles, logs and broadcasts to the customer dashboard" do
    application = applications(:processing_application)
    item = application.application_checklists.first
    assert item, "processing application needs checklist fixtures"

    assert_broadcasts "user_#{application.user_id}_dashboard", 1 do
      patch update_checklist_item_console_application_path(application, checklist_item_id: item.id),
            params: { completed: "true" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert item.reload.completed?
    assert_equal "checklist_updated", application.application_versions.recent.first.action
    assert_match "application-checklist", response.body
  end

  # --- Valuation -----------------------------------------------------------------

  test "valuation update validates range and records audit detail" do
    application = applications(:submitted_application)

    patch update_valuation_console_application_path(application), params: { property_valuation_middle: 50_000 }
    assert_match(/between/, flash[:alert])

    patch update_valuation_console_application_path(application),
          params: { property_valuation_middle: 1_650_000, valuation_explanation: "Independent valuation received" }
    assert_equal 1_650_000, application.reload.property_valuation_middle
    version = application.application_versions.recent.first
    assert_equal "valuation_updated", version.action
    assert_match "Independent valuation received", version.change_details
  end

  # --- Messages ----------------------------------------------------------------------

  test "draft and send-now message flows" do
    application = applications(:submitted_application)
    agent = AiAgent.active.first
    assert agent, "needs an active AiAgent fixture"

    assert_difference -> { application.application_messages.count } do
      post create_message_console_application_path(application), params: {
        application_message: { subject: "Hello {{user.first_name}}", content: "Checking in.", ai_agent_id: agent.id }
      }
    end
    draft = application.application_messages.order(:created_at).last
    assert draft.draft?

    patch send_message_console_application_path(application, message_id: draft.id)
    assert draft.reload.sent?

    post create_message_console_application_path(application), params: {
      send_now: "true",
      application_message: { subject: "Update", content: "Your documents are verified.", ai_agent_id: agent.id }
    }
    assert application.application_messages.order(:created_at).last.sent?
  end

  test "invalid message renders validation turbo stream" do
    application = applications(:submitted_application)
    agent = AiAgent.active.first

    post create_message_console_application_path(application),
         params: { application_message: { subject: "", content: "", ai_agent_id: agent.id } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "console-messages", response.body
  end

  # --- Documents ------------------------------------------------------------------------

  test "document verify, reject and request_all" do
    application = applications(:submitted_application)
    application.create_document_requests!
    doc = application.application_documents.first
    doc.update!(status: :uploaded, uploaded_at: Time.current)

    patch verify_console_application_document_path(application, doc)
    assert_equal "verified", doc.reload.status

    doc.update!(status: :uploaded)
    patch reject_console_application_document_path(application, doc), params: { reason: "Illegible scan" }
    assert_equal "rejected", doc.reload.status
    assert_equal "Illegible scan", doc.rejection_reason
  end

  # --- Scoping -----------------------------------------------------------------------------

  test "lender admins cannot reach other lenders' applications" do
    application = applications(:submitted_application) # futureproof-lender customer
    sign_in users(:lender_admin_user)

    get console_application_path(application)
    assert_response :not_found
  end
end
