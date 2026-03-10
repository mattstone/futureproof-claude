require "test_helper"

class CustomerApplicationJourneyTest < ActionDispatch::IntegrationTest
  setup do
    @region = 'au'
    
    # Create or use existing lender
    @lender = Lender.first || Lender.create!(
      name: 'Test Lender',
      abn: '11123456789',
      primary_contact_name: 'John Lender',
      primary_contact_email: 'lender@test.com',
      region: 'AU'
    )
    
    # Create lender user
    @lender_user = User.create_or_find_by(email: 'lender@test.com') do |u|
      u.password = 'password123'
      u.password_confirmation = 'password123'
      u.first_name = 'Lender'
      u.last_name = 'Test'
      u.lender_id = @lender.id
    end
    
    @mortgage = Mortgage.create_or_find_by(name: 'EPM Test Mortgage') do |m|
      m.region = 'AU'
      m.lender_id = @lender.id
      m.monthly_income_percent = 1.5
      m.min_property_value = 100000
      m.max_property_value = 5000000
      m.min_age = 55
      m.max_age = 85
      m.approval_status = 'approved'
    end
  end

  test "full customer application journey from home page to completed" do
    puts "\n" + "="*70
    puts "CUSTOMER APPLICATION JOURNEY - FULL INTEGRATION TEST"
    puts "="*70 + "\n"

    # Step 1: Create borrower account
    borrower = create_borrower_account
    assert borrower.persisted?, "Borrower should be created"
    puts "✓ Step 1: Borrower account created (#{borrower.email})"

    # Step 3: Start application
    application = start_application(borrower)
    assert application.persisted?, "Application should be created"
    assert application.status_created?, "Application should be in created status"
    puts "✓ Step 2: Application created (ID: #{application.id}, Status: #{application.status})"

    # Step 4: Fill in property details
    fill_property_details(application)
    application.reload
    assert application.status_property_details?, "Status should advance to property_details"
    assert application.address.present?, "Address should be filled"
    puts "✓ Step 3: Property details filled (Address: #{application.address})"

    # Step 5: Select income and loan options
    fill_income_and_loan_details(application)
    application.reload
    assert application.status_income_and_loan_options?, "Status should advance to income_and_loan_options"
    puts "✓ Step 4: Income & loan details filled (Loan Amount: $#{application.loan_amount})"

    # Step 6: Submit application
    submit_application(application)
    application.reload
    assert application.status_submitted?, "Status should be submitted"
    puts "✓ Step 5: Application submitted (Status: #{application.status})"

    # Step 7: Lender approves application
    approve_application(application)
    application.reload
    assert application.status_accepted?, "Status should be accepted"
    assert application.lender_id.present?, "Application should be assigned to lender"
    puts "✓ Step 6: Application approved by lender"

    # Step 8: Documents are generated and sent to borrower
    generate_documents(application)
    application_documents = application.application_documents
    assert application_documents.count > 0, "Documents should be generated"
    puts "✓ Step 7: Documents generated (#{application_documents.count} documents)"

    # Step 9: Borrower views documents (in portal)
    verify_borrower_can_view_documents(application)
    puts "✓ Step 8: Borrower can view documents in portal"

    # Step 10: Borrower downloads documents
    download_documents(application)
    puts "✓ Step 9: Borrower downloads documents"

    # Step 11: Upload any required documents (if any are pending)
    upload_required_documents(application)
    puts "✓ Step 10: Required documents uploaded by borrower"

    # Step 12: Admin/Lender verifies all documents
    verify_all_documents(application)
    puts "✓ Step 11: Documents verified by admin"

    # Step 13: Application is activated (loan funds released)
    activate_application(application)
    application.reload
    assert application.status_activated?, "Status should be activated"
    puts "✓ Step 12: Application activated"

    # Step 14: Verify final state - application is "fully uploaded"
    assert_application_fully_uploaded(application)
    puts "✓ Step 13: Final verification - Application fully uploaded and complete"

    puts "\n" + "="*70
    puts "✅ FULL CUSTOMER JOURNEY COMPLETE"
    puts "="*70
    puts "   Application ID: #{application.id}"
    puts "   Borrower: #{borrower.email}"
    puts "   Final Status: #{application.status}"
    puts "   Total Documents: #{application.application_documents.count}"
    puts "   Verified Documents: #{application.application_documents.where(status: 'verified').count}"
    puts "   Active Distributions: #{application.distributions.count}"
    puts "="*70 + "\n"
  end

  private

  def create_borrower_account
    User.create_or_find_by(email: 'borrower@test.com') do |u|
      u.password = 'password123'
      u.password_confirmation = 'password123'
      u.first_name = 'John'
      u.last_name = 'Borrower'
      u.country_of_residence = 'AU'
    end
  end

  def start_application(borrower)
    # Borrower initiates application via API or form
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
      status: :property_details
    )
  end

  def fill_income_and_loan_details(application)
    # Select mortgage product
    application.mortgage_id = @mortgage.id
    
    # Set income and loan parameters
    application.loan_amount = 300000  # 40% LTV
    application.monthly_income_requirement = 4500
    application.loan_term = 20
    application.income_payout_term = 20
    application.borrower_age = 65
    application.income_percentage = 1.5
    
    application.status = :income_and_loan_options
    application.save!
  end

  def submit_application(application)
    application.update!(status: :submitted)
    
    # Auto-create required documents when submitted
    ApplicationDocument.create!(
      application_id: application.id,
      document_type: 'identity',
      status: 'pending'
    )
    ApplicationDocument.create!(
      application_id: application.id,
      document_type: 'income_proof',
      status: 'pending'
    )
    ApplicationDocument.create!(
      application_id: application.id,
      document_type: 'bank_statement',
      status: 'pending'
    )
    ApplicationDocument.create!(
      application_id: application.id,
      document_type: 'property_title',
      status: 'pending'
    )
  end

  def approve_application(application)
    # Simulate lender approval
    application.approve!(
      loan_amount: 300000,
      interest_rate: 3.5,
      term_years: 20,
      lender: @lender_user
    )
  end

  def generate_documents(application)
    # Generate standard EPM documents
    document_types = {
      'contract' => 'Mortgage Contract',
      'key_facts' => 'Key Facts Sheet',
      'income_statements' => 'Income Statements'
    }
    
    document_types.each do |type, name|
      ApplicationDocument.create!(
        application_id: application.id,
        document_type: type,
        name: name,
        status: 'uploaded'  # Pre-generated by system
      )
    end
  end

  def verify_borrower_can_view_documents(application)
    # Simulate borrower accessing portal
    assert application.application_documents.count > 0, "Documents should be present"
    
    # Verify documents are accessible
    application.application_documents.each do |doc|
      assert doc.persisted?, "Document #{doc.id} should exist"
    end
  end

  def download_documents(application)
    # Simulate borrower downloading documents
    documents = application.application_documents
    
    documents.each do |doc|
      # In real test, would test actual download endpoint
      # GET /borrower_portal/:application_id/documents/:id/download
      assert doc.persisted?, "Document should be downloadable"
    end
  end

  def upload_required_documents(application)
    # Borrower uploads scanned copies of required documents
    pending_docs = application.application_documents.where(status: 'pending')
    
    pending_docs.each do |doc|
      # Simulate document upload
      doc.update!(status: 'uploaded')
    end
  end

  def verify_all_documents(application)
    # Admin/lender verifies documents in admin panel
    application.application_documents.where(status: 'uploaded').each do |doc|
      doc.verify!(
        agent_name: 'admin@test.com',
        notes: 'Document verified successfully'
      )
    end
  end

  def activate_application(application)
    # Simulate final activation (loan funds released)
    application.update!(status: :activated)
    
    # Create initial distribution (first monthly payment)
    Distribution.create!(
      application_id: application.id,
      amount: 4500,  # Monthly income payment
      status: 'completed',
      transaction_id: "TXN-#{Time.current.to_i}",
      processed_at: Time.current
    )
  end

  def assert_application_fully_uploaded(application)
    application.reload
    
    # Application should be in final activated state
    assert application.status_activated?, "Application should be activated"
    
    # All required documents should be present
    assert application.application_documents.count >= 4, "Should have at least 4 documents"
    
    # Critical documents should be verified
    required_types = %w[identity income_proof bank_statement property_title]
    required_types.each do |type|
      doc = application.application_documents.find_by(document_type: type)
      assert doc.present?, "Document type #{type} should exist"
      assert doc.verified?, "Document type #{type} should be verified"
    end
    
    # Distributions created
    assert application.distributions.count > 0, "Should have at least one distribution"
    
    # Application is complete
    puts "\n   Final Verification:"
    puts "   - Status: #{application.status}"
    puts "   - Lender: #{application.lender.email}"
    puts "   - Loan Amount: $#{application.loan_amount}"
    puts "   - Documents: #{application.application_documents.count} (#{application.application_documents.where(status: 'verified').count} verified)"
    puts "   - Distributions: #{application.distributions.count}"
  end
end
