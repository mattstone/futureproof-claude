require "test_helper"

class ApplicationFlowTest < ActionDispatch::IntegrationTest
  fixtures :users, :lenders, :mortgages

  def setup
    @user = users(:john)
    @futureproof_lender = lenders(:futureproof)
    @interest_only_mortgage = mortgages(:interest_only)
    @principal_interest_mortgage = mortgages(:principal_interest)
    
    # Ensure mortgages are properly linked to Futureproof lender
    [@interest_only_mortgage, @principal_interest_mortgage].each do |mortgage|
      MortgageLender.find_or_create_by(
        mortgage: mortgage,
        lender: @futureproof_lender,
        active: true
      )
    end
  end

  test "complete application process flow" do
    # Sign in user
    sign_in @user
    
    # Start new application
    get new_application_path
    assert_response :success
    assert_select "h1", "Property Details"
    
    # Create application with property details
    post applications_path, params: {
      application: {
        home_value: 1500000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 65,
        has_existing_mortgage: false,
        existing_mortgage_amount: 0
      }
    }
    
    application = @user.applications.last
    assert_not_nil application
    assert_equal "property_details", application.status
    assert_redirected_to income_and_loan_application_path(application)
    
    # Access income and loan page
    get income_and_loan_application_path(application)
    assert_response :success
    assert_select "h1", "Income & Loan Options"
    assert_select ".mortgage-type-cards .mortgage-card", 2  # Should have 2 mortgage options
    
    # Update with income and loan details
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
    assert_equal 25, application.loan_term
    assert_equal 20, application.income_payout_term
    assert_equal @principal_interest_mortgage.id, application.mortgage_id
    assert_equal 4.0, application.growth_rate
    assert_redirected_to summary_application_path(application)
    
    # Access summary page - this is where the bug occurred
    get summary_application_path(application)
    assert_response :success
    assert_select "h1", text: /Pre-approval Summary/i
    
    # Verify application details are displayed correctly
    assert_select ".summary-value", text: "$1,500,000"  # Home value
    assert_select ".summary-value", text: "Individual"  # Ownership
    assert_select ".summary-value", text: "25 years"    # Loan term
    assert_select ".summary-value", text: "20 years"    # Income payout
    assert_select ".summary-value", text: "Principal and Interest"  # Mortgage type
    assert_select ".summary-value", text: "4%"          # Growth rate
    
    # Submit application
    patch submit_application_path(application)
    
    application.reload
    assert_equal "submitted", application.status
    assert_redirected_to congratulations_application_path(application)
    
    # Verify congratulations page
    get congratulations_application_path(application)
    assert_response :success
    assert_select "h1", text: /congratulations|success/i
  end

  test "application process with lender ownership shows company name correctly" do
    sign_in @user
    
    # Create application with lender ownership
    post applications_path, params: {
      application: {
        home_value: 2000000,
        ownership_status: "lender",
        property_state: "investment",
        company_name: "Test Lending Corporation"
      }
    }
    
    application = @user.applications.last
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
    
    # Access summary page - this should now work with our fix
    get summary_application_path(application)
    assert_response :success
    
    # Verify company name is displayed correctly (this was the bug)
    assert_select ".summary-value", text: "Test Lending Corporation"
    assert_select ".summary-label", text: "Lender Name:"
  end

  test "application process with super fund ownership shows fund name correctly" do
    sign_in @user
    
    # Create application with super fund ownership
    post applications_path, params: {
      application: {
        home_value: 1800000,
        ownership_status: "super",
        property_state: "primary_residence",
        super_fund_name: "Smith Family SMSF"
      }
    }
    
    application = @user.applications.last
    assert_equal "super", application.ownership_status
    assert_equal "Smith Family SMSF", application.super_fund_name
    
    # Complete income and loan step
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 20,
        income_payout_term: 15,
        mortgage_id: @principal_interest_mortgage.id,
        growth_rate: 5.0
      }
    }
    
    # Access summary page
    get summary_application_path(application)
    assert_response :success
    
    # Verify super fund name is displayed
    assert_select ".summary-value", text: "Smith Family SMSF"
    assert_select ".summary-label", text: "Super Fund Name:"
  end

  test "application process with joint ownership" do
    sign_in @user
    
    # Create application with joint ownership
    borrower_names = JSON.generate([
      { "name" => "John Smith", "age" => 45 },
      { "name" => "Jane Smith", "age" => 42 }
    ])
    
    post applications_path, params: {
      application: {
        home_value: 2200000,
        ownership_status: "joint",
        property_state: "holiday",
        borrower_names: borrower_names
      }
    }
    
    application = @user.applications.last
    assert_equal "joint", application.ownership_status
    assert application.borrower_names.present?
    
    # Complete the flow
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 25,
        income_payout_term: 25,
        mortgage_id: @interest_only_mortgage.id,
        growth_rate: 6.0
      }
    }
    
    get summary_application_path(application)
    assert_response :success
    assert_select ".summary-value", text: "Joint Ownership"
  end

  test "mortgage options are correctly displayed and selectable" do
    sign_in @user
    
    # Create basic application
    post applications_path, params: {
      application: {
        home_value: 1500000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 60
      }
    }
    
    application = @user.applications.last
    
    # Access income and loan page
    get income_and_loan_application_path(application)
    assert_response :success
    
    # Should show both mortgage options
    assert_select ".mortgage-card", 2
    assert_select ".mortgage-card", text: /Interest Only/
    assert_select ".mortgage-card", text: /Principal and Interest/
    assert_select ".mortgage-badge", text: "Recommended"  # P&I should be recommended
    
    # Test selecting Interest Only mortgage
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 30,
        income_payout_term: 30,
        mortgage_id: @interest_only_mortgage.id,
        growth_rate: 2.0
      }
    }
    
    application.reload
    assert_equal @interest_only_mortgage.id, application.mortgage_id
    
    # Verify summary shows correct mortgage type
    get summary_application_path(application)
    assert_select ".summary-value", text: "Interest Only"
  end

  test "application validation errors are handled correctly" do
    sign_in @user
    
    # Try to create application without required fields
    post applications_path, params: {
      application: {
        home_value: "",
        ownership_status: "",
        property_state: ""
      }
    }
    
    # Should render the form again with errors
    assert_response :unprocessable_entity
    assert_select ".error-messages, .alert-danger"
  end

  test "income and loan validation requires mortgage selection" do
    sign_in @user
    
    # Create valid application
    post applications_path, params: {
      application: {
        home_value: 1500000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 60
      }
    }
    
    application = @user.applications.last
    
    # Try to submit income/loan without mortgage
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 25,
        income_payout_term: 20
        # mortgage_id missing
      }
    }
    
    # Should render with validation errors
    assert_response :unprocessable_entity
    assert_select ".error-messages, .alert-danger"
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
    assert_response :redirect
  end
end