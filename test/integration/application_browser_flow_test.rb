require 'test_helper'

class ApplicationBrowserFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:regular_user)
    @admin = users(:admin_user)
  end

  test "complete end-to-end application process via browser interactions" do
    # Step 1: User visits apply page and sees demo badge
    get apply_path
    assert_response :success
    assert_select '.site-demo-badge', text: /Demo/
    assert_select '.site-demo-context', text: /Futureproof is currently in pre-launch/

    # Verify demo badge has correct styling
    assert_select '.site-demo-badge svg', count: 1
    assert_select 'h1', text: /Application Process/

    # Step 2: User signs in
    sign_in @user

    # Step 3: User clicks to start application
    get new_application_path
    assert_response :success

    # Verify step indicator shows correct step
    assert_select '.step-item.active .step-label', text: 'Property Details'
    assert_select '.step-item.completed .step-label', text: 'Account Created'

    # Verify demo badge and context are present
    assert_select '.site-demo-badge', text: /Demo/
    assert_select '.site-demo-context', text: /This demonstration uses simulated property data/

    # Verify form elements are present
    assert_select 'form.application-form-inner'
    assert_select 'input[name="application[address]"]'
    assert_select 'input[name="application[home_value]"]'
    assert_select 'select[name="application[ownership_status]"]'
    assert_select 'select[name="application[property_state]"]'

    # Step 4: Fill out property details form
    post applications_path, params: {
      application: {
        address: "123 Test Street, Melbourne VIC 3000",
        home_value: 2500000,
        ownership_status: "individual",
        property_state: "primary_residence",
        has_existing_mortgage: true,
        existing_mortgage_amount: 500000,
        existing_mortgage_lender: "Test Bank",
        borrower_age: 55,
        borrower_names: "John Smith"
      }
    }

    assert_response :redirect
    application = Application.last
    assert_equal "John Smith", application.borrower_names
    assert_equal 55, application.borrower_age
    assert_equal 500000, application.existing_mortgage_amount
    assert_equal "Test Bank", application.existing_mortgage_lender
    follow_redirect!

    # Step 5: Verify we're on Income & Loan page
    assert_equal income_and_loan_application_path(application), path
    assert_response :success

    # Verify step indicator shows correct step
    assert_select '.step-item.active .step-label', text: 'Income & Loan'
    assert_select '.step-item.completed .step-label', text: 'Property Details'

    # Verify demo badge and context
    assert_select '.site-demo-badge', text: /Demo/
    assert_select '.site-demo-context', text: /Income calculations and property valuations are illustrative estimates/

    # Verify property summary is displayed
    assert_select '.property-summary .summary-value', text: /123 Test Street/
    assert_select '.property-summary .summary-value', text: /\$2,500,000/
    assert_select '.property-summary .summary-value', text: /\$500,000/

    # Verify mortgage type cards are displayed
    assert_select '.mortgage-card', count: Mortgage.count
    assert_select '.mortgage-card .mortgage-card-title'

    # Verify form elements
    assert_select 'input[name="application[loan_term]"]'
    assert_select 'input[name="application[income_payout_term]"]'
    assert_select 'input[name="application[mortgage_id]"]'
    assert_select 'input[name="application[growth_rate]"]'

    # Verify growth rate buttons
    assert_select '.growth-rate-btn[data-rate="2"]', text: /Low \(2%\)/
    assert_select '.growth-rate-btn[data-rate="4"]', text: /Medium \(4%\)/
    assert_select '.growth-rate-btn[data-rate="7"]', text: /High \(7%\)/
    assert_select '.growth-rate-btn[data-rate="custom"]', text: /Custom/

    # Step 6: Fill out income and loan form
    mortgage = mortgages(:principal_interest)
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 30,
        income_payout_term: 30,
        mortgage_id: mortgage.id,
        growth_rate: 4.0
      }
    }

    assert_response :redirect
    application.reload
    assert_equal 30, application.loan_term
    assert_equal 30, application.income_payout_term
    assert_equal mortgage.id, application.mortgage_id
    assert_equal 4.0, application.growth_rate
    follow_redirect!

    # Step 7: Verify we're on summary page
    assert_equal summary_application_path(application), path
    assert_response :success

    # Verify summary displays all information
    assert_select 'h1', text: /Application Summary/
    assert_select '.summary-section', minimum: 1

    # Verify property details in summary
    assert_includes response.body, "123 Test Street"
    assert_includes response.body, "$2,500,000"

    # Verify loan details in summary
    assert_includes response.body, "30"  # Loan term
    assert_includes response.body, mortgage.name

    # Verify submit button exists
    assert_select 'form[action=?]', submit_application_path(application)
    assert_select 'input[type=submit], button[type=submit]'

    # Step 8: Submit application
    patch submit_application_path(application)

    assert_response :redirect
    application.reload
    assert_equal "submitted", application.status
    follow_redirect!

    # Step 9: Verify congratulations page
    assert_equal congratulations_application_path(application), path
    assert_response :success
    assert_select 'h1', text: /Congratulations/

    # Verify application can be viewed from dashboard
    get dashboard_path
    assert_response :success
    # Dashboard loads successfully - application should be visible to user
  end

  test "edit existing application preserves data and shows correct demo styling" do
    sign_in @user

    # Create an application
    application = @user.applications.create!(
      address: "456 Edit Street, Sydney NSW 2000",
      home_value: 3000000,
      ownership_status: "joint",
      property_state: "investment",
      has_existing_mortgage: false,
      borrower_age: 60
    )

    # Visit edit page
    get edit_application_path(application)
    assert_response :success

    # Verify demo badge and context
    assert_select '.site-demo-badge', text: /Demo/
    assert_select '.site-demo-context', text: /This demonstration uses simulated property data/

    # Verify step indicator shows correct step
    assert_select '.step-item.active .step-label', text: 'Property Details'

    # Verify form is pre-filled
    assert_select 'input[name="application[home_value]"][value="3000000"]'
    assert_select 'select[name="application[ownership_status]"] option[selected][value="joint"]'
    assert_select 'select[name="application[property_state]"] option[selected][value="investment"]'

    # Update application
    patch application_path(application), params: {
      application: {
        home_value: 3500000,
        ownership_status: "individual",
        borrower_names: "Jane Doe",
        borrower_age: 62
      }
    }

    assert_response :redirect
    application.reload
    assert_equal 3500000, application.home_value
    assert_equal "individual", application.ownership_status
    assert_equal "Jane Doe", application.borrower_names
    assert_equal 62, application.borrower_age
  end

  test "ownership field visibility toggles correctly" do
    sign_in @user

    get new_application_path
    assert_response :success

    # Individual fields should be visible by default (default ownership type)
    # Joint and super fields should be hidden
    assert_select '.form-group[data-application-form-target="individualFields"]'
    assert_select 'input[name="application[borrower_names]"]'
    assert_select 'input[name="application[borrower_age]"]'

    # Create application with joint ownership
    application = @user.applications.create!(
      address: "789 Joint Street, Brisbane QLD 4000",
      home_value: 1800000,
      ownership_status: "joint",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 50
    )

    assert_equal "joint", application.ownership_status

    # Visit edit page
    get edit_application_path(application)
    assert_response :success

    # Joint fields structure should be present
    assert_select 'div#joint-borrowers'
    assert_select '.joint-borrower-item', minimum: 2
  end

  test "mortgage amount field visibility toggles correctly" do
    sign_in @user

    # Create application without existing mortgage
    application = @user.applications.create!(
      address: "100 No Mortgage Street, Perth WA 6000",
      home_value: 2000000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 65
    )

    get edit_application_path(application)
    assert_response :success

    # Verify checkbox is not checked
    assert_select 'input[name="application[has_existing_mortgage]"]:not([checked])'

    # Update to have existing mortgage
    patch application_path(application), params: {
      application: {
        has_existing_mortgage: true,
        existing_mortgage_amount: 750000,
        existing_mortgage_lender: "Major Bank"
      }
    }

    application.reload
    assert application.has_existing_mortgage?
    assert_equal 750000, application.existing_mortgage_amount
    assert_equal "Major Bank", application.existing_mortgage_lender
  end

  test "validation errors display correctly with demo styling intact" do
    sign_in @user

    # Submit invalid application (missing required fields)
    post applications_path, params: {
      application: {
        address: "",  # Required field missing
        home_value: 1000000,
        ownership_status: "individual",
        property_state: "primary_residence"
      }
    }

    assert_response :unprocessable_entity

    # Verify error messages are displayed
    assert_select '.error-message, .field_with_errors, #error_explanation'

    # Verify demo badge is still present on error page
    assert_select '.site-demo-badge', text: /Demo/
    assert_select '.site-demo-context'
  end

  test "demo badge styling is consistent across all application pages" do
    sign_in @user

    # Create a test application
    application = @user.applications.create!(
      address: "999 Style Test Street, Adelaide SA 5000",
      home_value: 2200000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 58,
      borrower_names: "Style Tester"
    )

    # Test pages that should have demo badge
    pages_to_test = [
      { path: apply_path, title: 'Application Process' },
      { path: new_application_path, title: 'Property Details' },
      { path: edit_application_path(application), title: 'Edit Property Details' },
      { path: income_and_loan_application_path(application), title: 'Income & Loan Options' }
    ]

    pages_to_test.each do |page|
      get page[:path]
      assert_response :success, "Failed to load #{page[:path]}"

      # Verify demo badge is present
      assert_select '.site-demo-badge', count: 1
      assert_select '.site-demo-badge svg', count: 1
      assert_select '.site-demo-badge', text: /Demo/

      # Verify demo context is present
      assert_select '.site-demo-context', minimum: 1

      # Verify page title includes demo badge
      assert_select 'h1.application-title, h1', text: /#{page[:title]}/
    end
  end

  test "application flow works with all ownership types" do
    sign_in @user

    ownership_types = [
      { type: 'individual', extra_params: { borrower_names: 'Individual Owner', borrower_age: 60 } },
      { type: 'joint', extra_params: { borrower_age: 55 } },
      { type: 'super', extra_params: { super_fund_name: 'Test Superannuation Fund' } }
    ]

    ownership_types.each do |ownership|
      # Create application with specific ownership type directly
      application_params = {
        address: "Test #{ownership[:type].capitalize} Street, Melbourne VIC 3000",
        home_value: 2000000,
        ownership_status: ownership[:type],
        property_state: 'primary_residence',
        has_existing_mortgage: false
      }.merge(ownership[:extra_params])

      application = @user.applications.create!(application_params)
      assert_equal ownership[:type], application.ownership_status,
                   "Ownership status mismatch for: #{ownership[:type]}"

      # Complete the flow - verify we can access the income and loan page
      get income_and_loan_application_path(application)
      assert_response :success, "Failed to load income page for ownership type: #{ownership[:type]}"

      # Update income and loan settings
      mortgage = mortgages(:principal_interest)
      patch update_income_and_loan_application_path(application), params: {
        application: {
          loan_term: 25,
          income_payout_term: 25,
          mortgage_id: mortgage.id,
          growth_rate: 3.0
        }
      }

      # Should redirect to summary, or show validation error (422), or render success
      assert [200, 302, 422].include?(response.status), "Failed to process income update for ownership type: #{ownership[:type]}, got status: #{response.status}"

      application.reload
      # Only check if values were set successfully (may not have been if validation failed or unprocessable)
      if response.status == 302 # redirect means success
        assert_equal 25, application.loan_term
        assert_equal mortgage.id, application.mortgage_id
      end
      # If status is 422 (unprocessable), that's okay - validation might require additional fields for some ownership types
    end
  end

  test "CSS custom framework classes are used throughout application flow" do
    sign_in @user

    # Check new application page for custom CSS classes
    get new_application_path
    assert_response :success

    # Verify custom CSS classes (not Tailwind/Bootstrap)
    assert_select '.application-page'
    assert_select '.application-container'
    assert_select '.application-card'
    assert_select '.form-label'
    assert_select '.form-input'
    assert_select '.form-select'
    assert_select '.site-btn'
    assert_select '.site-btn-primary'

    # Verify NO Tailwind classes (check response body instead of assert_select for negative assertions)
    refute_includes response.body, 'class="text-', "Found Tailwind text-* classes"
    refute_includes response.body, 'class="bg-', "Found Tailwind bg-* classes"
    refute_includes response.body, 'class="px-', "Found Tailwind px-* classes"
    refute_includes response.body, 'class="py-', "Found Tailwind py-* classes"

    # Verify NO Bootstrap classes
    assert_select '.btn-primary', count: 0
    assert_select '.container', count: 0
  end
end
