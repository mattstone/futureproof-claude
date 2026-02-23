require "test_helper"

class ApplicationDocumentTest < ActiveSupport::TestCase
  setup do
    @application = applications(:mortgage_application)
    @document = @application.application_documents.create!(
      document_type: "identity",
      status: "pending",
      name: "Identity Document",
      requested_at: Time.current
    )
  end

  test "valid document" do
    assert @document.valid?
  end

  test "requires document_type" do
    @document.document_type = nil
    assert_not @document.valid?
  end

  test "validates document_type inclusion" do
    @document.document_type = "invalid_type"
    assert_not @document.valid?
  end

  test "requires rejection_reason when rejected" do
    @document.status = :rejected
    @document.rejection_reason = nil
    assert_not @document.valid?
    assert_includes @document.errors[:rejection_reason], "can't be blank"
  end

  test "verify! sets verified fields" do
    @document.update!(status: :uploaded)
    @document.verify!(agent_name: "Test Agent", notes: "Looks good")
    @document.reload

    assert @document.verified?
    assert_equal "Test Agent", @document.verified_by
    assert_not_nil @document.verified_at
    assert_equal "Looks good", @document.notes
  end

  test "reject! sets rejection fields" do
    @document.update!(status: :uploaded)
    @document.reject!(agent_name: "Test Agent", reason: "Blurry image")
    @document.reload

    assert @document.rejected?
    assert_equal "Blurry image", @document.rejection_reason
    assert_equal "Test Agent", @document.verified_by
  end

  test "outstanding scope returns pending and rejected" do
    @document.update!(status: :pending)
    rejected_doc = @application.application_documents.create!(
      document_type: "bank_statement", status: "rejected", rejection_reason: "Bad quality"
    )
    verified_doc = @application.application_documents.create!(
      document_type: "income_proof", status: "verified"
    )

    outstanding = @application.application_documents.outstanding
    assert_includes outstanding, @document
    assert_includes outstanding, rejected_doc
    assert_not_includes outstanding, verified_doc
  end

  test "complete scope returns uploaded and verified" do
    @document.update!(status: :uploaded)
    verified_doc = @application.application_documents.create!(
      document_type: "income_proof", status: "verified"
    )

    complete = @application.application_documents.complete
    assert_includes complete, @document
    assert_includes complete, verified_doc
  end

  test "create_document_requests! creates all document types" do
    @application.application_documents.destroy_all
    @application.create_document_requests!
    assert_equal ApplicationDocument::DOCUMENT_TYPES.length, @application.application_documents.count
  end

  test "create_document_requests! is idempotent" do
    @application.application_documents.destroy_all
    @application.create_document_requests!
    @application.create_document_requests!
    assert_equal ApplicationDocument::DOCUMENT_TYPES.length, @application.application_documents.count
  end

  test "documents_complete_for? checks verified docs" do
    @application.application_documents.destroy_all
    assert_not @application.documents_complete_for?(:submission)

    ApplicationDocument::REQUIRED_FOR_SUBMISSION.each do |doc_type|
      @application.application_documents.create!(document_type: doc_type, status: "verified")
    end
    assert @application.documents_complete_for?(:submission)
  end

  test "outstanding_documents returns pending and rejected" do
    @document.update!(status: :pending)
    assert_includes @application.outstanding_documents, @document
  end

  test "display_name falls back to humanized type" do
    @document.name = nil
    assert_equal "Identity", @document.display_name
  end
end
