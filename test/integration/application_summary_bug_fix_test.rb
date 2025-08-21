require "test_helper"

class ApplicationSummaryBugFixTest < ActionDispatch::IntegrationTest
  def setup
    # Use existing fixture data
    @lender = lenders(:futureproof)
    @user = users(:john)
    @mortgage = mortgages(:interest_only)
    
    # Ensure mortgages are properly linked to Futureproof lender
    MortgageLender.find_or_create_by(
      mortgage: @mortgage,
      lender: @lender,
      active: true
    )
  end

  test "application summary displays lender name correctly for lender ownership" do
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
        mortgage_id: @mortgage.id,
        growth_rate: 3.0
      }
    }

    # This should now work without the lender_name error
    get summary_application_path(application)
    assert_response :success
    
    # Verify we're on the summary page (the page content might vary)
    # The key test is that we don't get the lender_name error
    assert_response :success
    
    # The main test: Verify the company name is displayed without error (the bug we fixed)
    # This would have failed with "undefined method 'lender_name'" before the fix
    assert_select ".summary-value", text: "Test Lending Corporation"
    assert_select ".summary-label", text: "Lender Name:"
  end

  test "application summary does not show lender name section for individual ownership" do
    # Sign in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }

    # Create application with individual ownership (no company_name)
    post applications_path, params: {
      application: {
        home_value: 2000000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 65
      }
    }

    application = @user.applications.last
    assert_equal "individual", application.ownership_status
    assert_nil application.company_name

    # Complete income and loan step
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 25,
        income_payout_term: 20,
        mortgage_id: @mortgage.id,
        growth_rate: 4.0
      }
    }

    # Access summary page
    get summary_application_path(application)
    assert_response :success
    
    # Should NOT show lender name section since company_name is nil
    assert_select ".summary-label", text: "Lender Name:", count: 0
  end

  test "application summary shows super fund name correctly for super ownership" do
    # Sign in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }

    # Create application with super fund ownership
    post applications_path, params: {
      application: {
        home_value: 1800000,
        ownership_status: "super",
        property_state: "investment",
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
        mortgage_id: @mortgage.id,
        growth_rate: 5.0
      }
    }

    # Access summary page
    get summary_application_path(application)
    assert_response :success
    
    # Verify super fund name is displayed
    assert_select ".summary-value", text: "Smith Family SMSF"
    assert_select ".summary-label", text: "Super Fund Name:"
    
    # Should not show lender name section
    assert_select ".summary-label", text: "Lender Name:", count: 0
  end

  test "application can proceed from summary to submission" do
    # Sign in
    post user_session_path, params: {
      user: { email: @user.email, password: 'password123' }
    }

    # Create and complete application
    post applications_path, params: {
      application: {
        home_value: 1600000,
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 60
      }
    }

    application = @user.applications.last
    
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 30,
        income_payout_term: 30,
        mortgage_id: @mortgage.id,
        growth_rate: 2.0
      }
    }

    get summary_application_path(application)
    assert_response :success

    # Submit the application
    patch submit_application_path(application)
    
    application.reload
    assert_equal "submitted", application.status
    assert_redirected_to congratulations_application_path(application)
    
    # Verify congratulations page loads
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /congratulations|success/i
  end
end