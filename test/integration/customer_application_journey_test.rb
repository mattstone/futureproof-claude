require "test_helper"

class CustomerApplicationJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @region = 'au'

    # Create or use existing lender
    @lender = Lender.first || Lender.create!(
      name: 'Test Lender',
      contact_email: 'lender@test.com',
      lender_type: :lender,
      country: 'AU'
    )

    @mortgage = Mortgage.first || Mortgage.create!(
      name: 'EPM Test Mortgage',
      mortgage_type: :interest_only,
      lvr: 80,
      status: :active
    )
  end

  test "full customer application journey from home page to completed" do
    # Step 1: Create borrower account
    borrower = create_borrower_account
    assert borrower.persisted?, "Borrower should be created"

    # Step 2: Start application
    application = start_application(borrower)
    assert application.persisted?, "Application should be created"
    assert application.status_created?, "Application should be in created status"

    # Step 3: Fill in property details
    fill_property_details(application)
    application.reload
    assert application.status_property_details?, "Status should advance to property_details"
    assert application.address.present?, "Address should be filled"

    # Step 4: Select income and loan options
    fill_income_and_loan_details(application)
    application.reload
    assert application.status_income_and_loan_options?, "Status should advance to income_and_loan_options"

    # Step 5: Submit application
    submit_application(application)
    application.reload
    assert application.status_submitted?, "Status should be submitted"

    # Step 6: Lender approves application
    approve_application(application)
    application.reload
    assert application.status_accepted?, "Status should be accepted"
    assert application.lender_id.present?, "Application should be assigned to lender"

    # Step 7: Documents are generated
    generate_documents(application)
    assert application.application_documents.count > 0, "Documents should be generated"

    # Step 8: Borrower views documents
    verify_borrower_can_view_documents(application)

    # Step 9: Upload required documents
    upload_required_documents(application)

    # Step 10: Admin verifies all documents
    verify_all_documents(application)

    # Step 11: Application is activated
    activate_application(application)
    application.reload
    assert application.status_activated?, "Status should be activated"

    # Step 12: Verify final state
    assert_application_fully_uploaded(application)
  end

  private

  def create_borrower_account
    User.create!(
      email: "journey_borrower_#{Time.current.to_i}@test.com",
      password: 'password123!',
      password_confirmation: 'password123!',
      first_name: 'John',
      last_name: 'Borrower',
      country_of_residence: 'AU',
      terms_accepted: true,
      confirmed_at: Time.current
    )
  end

  def start_application(borrower)
    Application.create!(
      user_id: borrower.id,
      home_value: 750000,
      ownership_status: :individual,
      property_state: :primary_residence,
      region: 'AU',
      status: :created,
      growth_rate: 6.0
    )
  end

  def fill_property_details(application)
    application.update!(
      address: '123 Main Street, Sydney NSW 2000, Australia',
      has_existing_mortgage: false,
      borrower_age: 65,
      borrower_names: 'John Borrower',
      status: :property_details
    )
  end

  def fill_income_and_loan_details(application)
    application.update!(
      mortgage_id: @mortgage.id,
      equity_investment_amount: 300000,
      investment_term: 20,
      income_payout_term: 20,
      borrower_age: 65,
      status: :income_and_loan_options
    )
  end

  def submit_application(application)
    application.update!(status: :submitted)

    # Auto-create required documents when submitted
    %w[identity income_proof bank_statement property_title].each do |doc_type|
      ApplicationDocument.create!(
        application_id: application.id,
        document_type: doc_type,
        status: 'pending'
      )
    end
  end

  def approve_application(application)
    application.approve!(
      loan_amount: 300000,
      interest_rate: 3.5,
      term_years: 20,
      lender: @lender
    )
  end

  def generate_documents(application)
    # Generate additional documents (using valid document types)
    { 'insurance' => 'Insurance Certificate', 'property_valuation' => 'Property Valuation' }.each do |type, name|
      ApplicationDocument.create!(
        application_id: application.id,
        document_type: type,
        name: name,
        status: 'uploaded'
      )
    end
  end

  def verify_borrower_can_view_documents(application)
    assert application.application_documents.count > 0, "Documents should be present"
    application.application_documents.each do |doc|
      assert doc.persisted?, "Document #{doc.id} should exist"
    end
  end

  def upload_required_documents(application)
    application.application_documents.where(status: 'pending').each do |doc|
      doc.update!(status: 'uploaded')
    end
  end

  def verify_all_documents(application)
    application.application_documents.where(status: 'uploaded').each do |doc|
      doc.verify!(
        agent_name: 'admin@test.com',
        notes: 'Document verified successfully'
      )
    end
  end

  def activate_application(application)
    application.update!(status: :activated)

    Distribution.create!(
      application_id: application.id,
      amount: 4500,
      status: 'completed',
      transaction_id: "TXN-#{Time.current.to_i}",
      processed_at: Time.current,
      distribution_date: Date.current,
      payment_method: 'bank_transfer'
    )
  end

  def assert_application_fully_uploaded(application)
    application.reload

    assert application.status_activated?, "Application should be activated"
    assert application.application_documents.count >= 4, "Should have at least 4 documents"

    %w[identity income_proof bank_statement property_title].each do |type|
      doc = application.application_documents.find_by(document_type: type)
      assert doc.present?, "Document type #{type} should exist"
      assert doc.verified?, "Document type #{type} should be verified"
    end

    assert application.distributions.count > 0, "Should have at least one distribution"
  end
end
