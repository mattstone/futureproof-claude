class MockDocumentVerificationService
  REJECTION_REASONS = [
    "Document appears blurry or illegible",
    "Wrong document type submitted",
    "Document has expired",
    "Document is partially obscured",
    "Unable to verify authenticity"
  ].freeze

  def self.verify_document(document)
    # Deterministic results based on document ID
    seed = document.id % 20

    if seed < 17 # 85% verified
      {
        status: "verified",
        confidence: 0.90 + (seed % 10) * 0.01,
        checks: { format: "pass", legibility: "pass", authenticity: "pass", expiry: "pass" },
        notes: "Document verified successfully"
      }
    elsif seed < 19 # 10% rejected
      {
        status: "rejected",
        confidence: 0.75 + (seed % 5) * 0.03,
        checks: { format: "pass", legibility: "fail", authenticity: "pass", expiry: "pass" },
        notes: REJECTION_REASONS[seed % REJECTION_REASONS.length]
      }
    else # 5% needs_review
      {
        status: "needs_review",
        confidence: 0.55 + (seed % 10) * 0.02,
        checks: { format: "pass", legibility: "pass", authenticity: "uncertain", expiry: "pass" },
        notes: "Document requires manual review - authenticity uncertain"
      }
    end
  end

  def self.classify_document(file_metadata)
    types = ApplicationDocument::DOCUMENT_TYPES
    predicted = types[file_metadata.hash.abs % types.length]
    { predicted_type: predicted, confidence: 0.80 + (file_metadata.hash.abs % 20) * 0.01 }
  end

  def self.extract_data(document)
    case document.document_type
    when "identity"
      { full_name: "John Smith", date_of_birth: "1965-03-15", document_number: "PA#{document.id}12345", expiry_date: "2028-03-15" }
    when "income_proof"
      { employer: "Acme Corp", annual_income: 95000, pay_frequency: "monthly", year: 2025 }
    when "bank_statement"
      { bank: "Commonwealth Bank", account_type: "savings", balance: 45000, period: "last 3 months" }
    when "property_title"
      { title_reference: "SP#{document.id}789", registered_owners: "John Smith", encumbrances: "None" }
    when "insurance"
      { provider: "NRMA", policy_number: "INS-#{document.id}", coverage: 500000, expiry: "2026-12-31" }
    when "property_valuation"
      { valuer: "CoreLogic", estimated_value: 750000, valuation_date: Date.current.to_s, confidence: "high" }
    else
      { raw_text: "Extracted content from #{document.document_type}", pages: 2, language: "en" }
    end
  end
end
