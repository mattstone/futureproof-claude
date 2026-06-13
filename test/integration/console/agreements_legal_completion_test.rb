require "test_helper"

class Console::AgreementsLegalCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @agreement = agreements(:draft_broker_agreement)
  end

  # --- Agreement show depth ---------------------------------------------------------

  test "agreement page shows details, two-party panel and audit trail" do
    get console_agreement_path(@agreement)
    assert_select ".console-card-title", text: "Details"
    assert_select ".console-dl-term", text: "Template"
    assert_select ".console-dl-term", text: "Created by"
    assert_select ".console-sig-card", count: 2
    assert_match "Awaiting signature", response.body
    assert_select ".console-card-title", text: "Audit trail"
    assert_match "Agreement created", response.body
  end

  test "audit trail records the full signing journey with IPs" do
    @agreement.send_for_signing!
    @agreement.record_signature!(role: "counterparty", signer_name: "Pat Partner",
                                 signer_email: "pat@partner.example", signer_title: "Director",
                                 typed_signature: "Pat Partner", ip_address: "203.0.113.7")

    get console_agreement_path(@agreement)
    assert_match "Sent for signing", response.body
    assert_match "Signed as Counterparty", response.body
    assert_match "203.0.113.7", response.body
    assert_select ".console-sig-signed", count: 1
    assert_select ".console-sig-pending", count: 1
  end

  # --- Expiry --------------------------------------------------------------------------

  test "expiry is captured on edit and surfaced when approaching" do
    patch console_agreement_path(@agreement), params: {
      agreement: { title: @agreement.title, expires_at: 30.days.from_now.to_date }
    }
    assert_equal 30.days.from_now.to_date, @agreement.reload.expires_at.to_date

    @agreement.update_columns(status: Agreement.statuses[:fully_executed])
    assert @agreement.reload.expiring_soon?

    get console_agreement_path(@agreement)
    assert_match(/Expires \d+ \w+ \d{4}/, response.body)
  end

  test "past expiry reads expired and counts on the index" do
    @agreement.update_columns(status: Agreement.statuses[:fully_executed],
                              executed_at: 1.year.ago, expires_at: 1.day.ago)

    assert @agreement.reload.expired_by_date?

    get console_agreement_path(@agreement)
    assert_match(/Expired \d+ \w+ \d{4}/, response.body)

    get console_agreements_path
    assert_select ".console-stat-label", text: "Expiring ≤ 60 days"
  end

  # --- Renewal -------------------------------------------------------------------------

  test "renewing an executed agreement creates a linked draft at the current template version" do
    @agreement.update_columns(status: Agreement.statuses[:fully_executed], executed_at: Time.current)

    assert_difference -> { Agreement.count }, 1 do
      assert_difference -> { AuditLog.where(action: "agreement_renewed").count }, 1 do
        post renew_console_agreement_path(@agreement)
      end
    end

    renewal = Agreement.order(:created_at).last
    assert renewal.status_draft?
    assert_equal @agreement.agreeable, renewal.agreeable
    assert_equal @agreement.legal_document, renewal.legal_document
    assert_match "Renewal of agreement ##{@agreement.id}", renewal.notes
    assert_redirected_to console_agreement_path(renewal)
  end

  test "draft agreements cannot be renewed" do
    assert_no_difference -> { Agreement.count } do
      post renew_console_agreement_path(@agreement)
    end
    assert_match(/Only executed or expired/, flash[:alert])
  end

  # --- Legal documents depth --------------------------------------------------------------

  test "legal document page shows the version family" do
    document = legal_documents(:terms_us_active_v2) rescue LegalDocument.where(is_active: true).first
    sibling = LegalDocument.create!(document_type: document.document_type, jurisdiction: document.jurisdiction,
                                    party_type: document.party_type, title: document.title,
                                    content: "<h1>Next version</h1>", version: document.version.to_i + 5,
                                    status: "draft", is_draft: true, is_active: false,
                                    effective_from: Date.current)

    get console_legal_document_path(document)
    assert_select ".console-card-title", text: "Other versions"
    assert_select "a", text: "v#{sibling.version}"
  end

  test "legal document page links agreements generated from it" do
    document = @agreement.legal_document

    get console_legal_document_path(document)
    assert_select ".console-card-title", text: "Agreements from this template"
    assert_select "a", text: @agreement.title
  end
end
