require "test_helper"

class MockDocumentVerificationServiceTest < ActiveSupport::TestCase
  setup do
    @application = applications(:mortgage_application)
    @document = @application.application_documents.create!(
      document_type: "identity",
      status: "uploaded",
      name: "Identity Document"
    )
  end

  test "verify_document returns hash with required keys" do
    result = MockDocumentVerificationService.verify_document(@document)
    assert_includes %w[verified rejected needs_review], result[:status]
    assert result[:confidence].is_a?(Numeric)
    assert result[:checks].is_a?(Hash)
    assert result[:notes].is_a?(String)
  end

  test "verify_document is deterministic for same document" do
    result1 = MockDocumentVerificationService.verify_document(@document)
    result2 = MockDocumentVerificationService.verify_document(@document)
    assert_equal result1, result2
  end

  test "verify_document checks include expected keys" do
    result = MockDocumentVerificationService.verify_document(@document)
    assert result[:checks].key?(:format)
    assert result[:checks].key?(:legibility)
    assert result[:checks].key?(:authenticity)
    assert result[:checks].key?(:expiry)
  end

  test "classify_document returns predicted type and confidence" do
    result = MockDocumentVerificationService.classify_document({ filename: "payslip.pdf" })
    assert result[:predicted_type].present?
    assert_includes ApplicationDocument::DOCUMENT_TYPES, result[:predicted_type]
    assert result[:confidence].is_a?(Numeric)
  end

  test "extract_data returns relevant data for identity" do
    result = MockDocumentVerificationService.extract_data(@document)
    assert result[:full_name].present?
    assert result[:document_number].present?
  end

  test "extract_data returns relevant data for bank_statement" do
    @document.update!(document_type: "bank_statement")
    result = MockDocumentVerificationService.extract_data(@document)
    assert result[:bank].present?
    assert result[:balance].present?
  end

  test "extract_data returns generic data for unknown types" do
    @document.update!(document_type: "tax_return")
    result = MockDocumentVerificationService.extract_data(@document)
    assert result[:raw_text].present?
  end
end
