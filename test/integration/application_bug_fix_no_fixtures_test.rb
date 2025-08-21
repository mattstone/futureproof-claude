require "test_helper"

class ApplicationBugFixNoFixturesTest < ActionDispatch::IntegrationTest
  # Disable fixtures for this test class
  self.use_transactional_tests = false

  def setup
    # Clean database before each test
    clean_database
    
    # Create test data manually without fixtures
    @lender = Lender.create!(
      name: 'Futureproof',
      lender_type: :futureproof,
      contact_email: 'test@futureproof.com',
      country: 'Australia'
    )
    
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'Australia',
      lender: @lender,
      terms_accepted: true,
      confirmed_at: Time.current
    )
    
    @interest_only_mortgage = Mortgage.create!(
      name: 'Interest Only',
      mortgage_type: :interest_only,
      lvr: 80.0,
      status: :active
    )
    
    @principal_interest_mortgage = Mortgage.create!(
      name: 'Principal and Interest',
      mortgage_type: :principal_and_interest,
      lvr: 80.0,
      status: :active
    )
    
    # Link mortgages to lender
    [@interest_only_mortgage, @principal_interest_mortgage].each do |mortgage|
      MortgageLender.create!(
        mortgage: mortgage,
        lender: @lender,
        active: true
      )
    end
  end

  def teardown
    # Clean up after each test
    clean_database
  end

  test "application summary displays lender name correctly for lender ownership - BUG FIX TEST" do
    # Sign in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    assert_response :redirect

    # Create application with lender ownership
    post applications_path, params: {
      application: {
        home_value: 1500000,
        ownership_status: "lender",
        property_state: "primary_residence",
        company_name: "Test Lending Corporation"
      }
    }

    application = @user.applications.last
    assert_not_nil application
    assert_equal "lender", application.ownership_status
    assert_equal "Test Lending Corporation", application.company_name

    # Complete income and loan step
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 30,
        income_payout_term: 25,
        mortgage_id: @interest_only_mortgage.id,
        growth_rate: 3.0
      }
    }

    # This should now work without the lender_name error
    get summary_application_path(application)
    assert_response :success
    
    # Verify the page content (this was the bug)
    assert_select "h1", text: /Pre-approval Summary/i
    assert_select ".summary-value", text: "Test Lending Corporation"
    assert_select ".summary-label", text: "Lender Name:"
    
    # Verify other application details
    assert_select ".summary-value", text: "$1,500,000"
    assert_select ".summary-value", text: "Lender"
    assert_select ".summary-value", text: "30 years"
    assert_select ".summary-value", text: "25 years"
    assert_select ".summary-value", text: "Interest Only"
    assert_select ".summary-value", text: "3%"
  end

  test "complete application flow without fixtures works correctly" do
    # Sign in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }
    assert_response :redirect

    # Create application
    post applications_path, params: {
      application: {
        home_value: 2000000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 65
      }
    }

    application = @user.applications.last
    assert_not_nil application
    assert_equal "property_details", application.status
    
    # Complete income and loan step
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 25,
        income_payout_term: 20,
        mortgage_id: @principal_interest_mortgage.id,
        growth_rate: 4.0
      }
    }

    application.reload
    assert_equal "income_and_loan_options", application.status

    # Access summary page (this was where the original bug occurred)
    get summary_application_path(application)
    assert_response :success
    assert_select "h1", text: /Pre-approval Summary/i
    
    # Submit application
    patch submit_application_path(application)
    
    application.reload
    assert_equal "submitted", application.status
    assert_redirected_to congratulations_application_path(application)
  end

  test "application summary does not show lender name section for individual ownership" do
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }

    # Create application with individual ownership (no company_name)
    post applications_path, params: {
      application: {
        home_value: 1800000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 55
      }
    }

    application = @user.applications.last
    assert_equal "individual", application.ownership_status
    assert_nil application.company_name

    # Complete income and loan step
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 30,
        income_payout_term: 30,
        mortgage_id: @principal_interest_mortgage.id,
        growth_rate: 2.0
      }
    }

    # Access summary page
    get summary_application_path(application)
    assert_response :success
    
    # Should NOT show lender name section since company_name is nil
    assert_select ".summary-label", text: "Lender Name:", count: 0
  end

  private
  
  def clean_database
    # Get all table names except schema info tables
    tables = ActiveRecord::Base.connection.tables.reject do |table|
      %w[schema_migrations ar_internal_metadata].include?(table)
    end
    
    # Disable foreign key checks temporarily for PostgreSQL
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica'")
    end
    
    # Truncate all tables
    tables.each do |table|
      begin
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{ActiveRecord::Base.connection.quote_table_name(table)} CASCADE")
      rescue => e
        # If truncate fails, try delete
        begin
          ActiveRecord::Base.connection.execute("DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(table)}")
        rescue => delete_error
          puts "Warning: Could not clean table #{table}: #{delete_error.message}"
        end
      end
    end
    
    # Re-enable foreign key checks for PostgreSQL
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin'")
    end
  end
end