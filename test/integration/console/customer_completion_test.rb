require "test_helper"

class Console::CustomerCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @customer = users(:regular_user)
    @application = @customer.applications.order(created_at: :desc).first
  end

  # --- Journey ---------------------------------------------------------------------

  test "journey card lists applications with status, property and contract link" do
    get console_user_path(@customer)
    assert_select ".console-card-title", text: "Journey"
    assert_select "a", text: "Application ##{@application.id}"

    if (contract = @application.contract)
      assert_select "a[href=?]", console_contract_path(contract), text: "Contract"
    end
  end

  test "stalled applications are flagged on the journey" do
    @application.update_columns(status: Application.statuses[:processing], updated_at: 10.days.ago)

    get console_user_path(@customer)
    assert_match(/Stalled \d+d/, response.body)
  end

  # --- Verification ------------------------------------------------------------------

  test "verification card shows KYC and AML state per application" do
    KycSubmission.find_or_initialize_by(application: @application).update!(status: :verified, verification_type: "government_id")
    AmlCheck.find_or_initialize_by(application: @application).update!(status: :passed, risk_level: "low")

    get console_user_path(@customer)
    assert_select ".console-card-title", text: "Verification"
    assert_match "KYC Verified", response.body
    assert_match "AML Passed", response.body
    assert_match "low risk", response.body
  end

  test "missing verification reads not started, not blank" do
    @application.kyc_submission&.destroy
    @application.aml_check&.destroy

    get console_user_path(@customer)
    assert_match "KYC not started", response.body
    assert_match "AML not started", response.body
  end

  # --- Quotes -------------------------------------------------------------------------

  test "quotes card shows immutable versioned quotes" do
    Quote.create!(application: @application, product_version: "v14d-optimised", pricing_model: "pavel",
                  mortgage_type: "interest_only", region: "AU", home_value: 1_500_000,
                  term_years: 25, income_payout_term: 25, annuity_rate: 0.0125, lvr: 0.8,
                  max_loan: 1_200_000, monthly_income: 1_875, annual_income: 22_500,
                  total_income: 562_500, issued_at: Time.current)

    get console_user_path(@customer)
    assert_select ".console-card-title", text: "Quotes"
    assert_match "v14d-optimised", response.body
    assert_match "Quotes are immutable and versioned", response.body
    assert_match "25 years", response.body
  end

  # --- Communications ------------------------------------------------------------------

  test "communications card lists AI conversations and support tickets" do
    conversation = ChatConversation.create!(user: @customer, chat_agent: ChatAgent.first,
                                            region: "au", status: "active", subject: "Income question")
    ticket = SupportTicket.create!(subject: "Statement request", sender_email: @customer.email,
                                   sender_name: @customer.display_name, user: @customer,
                                   status: "open", priority: "normal", source: "email",
                                   ticket_number: "FP-TEST-00001")

    get console_user_path(@customer)
    assert_select ".console-card-title", text: "Communications"
    assert_select "a[href=?]", console_chat_conversation_path(conversation), text: "Income question"
    assert_select "a[href=?]", console_support_ticket_path(ticket)
  end

  # --- Legal acceptances -----------------------------------------------------------------

  test "legal acceptances card shows what was accepted and when" do
    document = LegalDocument.first or flunk "needs a legal document fixture"

    LegalDocumentAcceptance.create!(user: @customer, legal_document: document,
                                    accepted_at: Time.current, acceptance_type: "explicit")

    get console_user_path(@customer)
    assert_select ".console-card-title", text: "Legal acceptances"
    assert_select ".console-doc-name strong", text: document.title
  end

  test "customers without acceptance records fall back to the legacy signup flag" do
    @customer.legal_document_acceptances.destroy_all
    @customer.update_columns(terms_accepted: true)

    get console_user_path(@customer)
    assert_match "Terms were accepted at signup", response.body
  end
end
