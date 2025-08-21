require "application_system_test_case"

class ApplicationProcessTest < ApplicationSystemTestCase
  fixtures :users, :lenders, :mortgages

  def setup
    # Set up test data
    @user = users(:john)
    @futureproof_lender = lenders(:futureproof)
    @interest_only_mortgage = mortgages(:interest_only)
    @principal_interest_mortgage = mortgages(:principal_interest)
    
    # Ensure mortgages are active and linked to Futureproof
    [@interest_only_mortgage, @principal_interest_mortgage].each do |mortgage|
      mortgage.update!(status: :active, lvr: 80.0)
      MortgageLender.find_or_create_by(
        mortgage: mortgage,
        lender: @futureproof_lender,
        active: true
      )
    end

    # Ensure user is linked to Futureproof lender
    @user.update!(lender: @futureproof_lender)
  end

  test "complete application process from start to summary" do
    # Step 1: Sign in
    sign_in @user
    visit dashboard_path

    # Step 2: Start new application
    click_on "Apply Now"
    assert_current_path new_application_path

    # Verify the page loaded correctly
    assert_selector "h1", text: "Property Details"
    assert_selector ".step-item.active", text: "2"

    # Step 3: Fill out property details for Individual ownership
    within(".application-form") do
      # Set home value using slider
      slider = find('input[type="range"][name="application[home_value]"]')
      # Set to $2M
      execute_script("arguments[0].value = 2000000; arguments[0].dispatchEvent(new Event('input'))", slider)
      
      # Verify the slider value updated
      assert_selector(".slider-value", text: "$2,000,000")
      
      # Select ownership status
      select "Individual", from: "application[ownership_status]"
      
      # Select property type
      select "Primary Residence", from: "application[property_state]"
      
      # Set borrower age (should be visible for individual ownership)
      age_slider = find('input[type="range"][name="application[borrower_age]"]')
      execute_script("arguments[0].value = 65; arguments[0].dispatchEvent(new Event('input'))", age_slider)
      
      # Check existing mortgage
      check "This property has an existing mortgage"
      
      # Wait for mortgage amount field to appear
      assert_selector('.mortgage-amount-group', visible: true)
      
      # Set mortgage amount
      mortgage_slider = find('input[type="range"][name="application[existing_mortgage_amount]"]')
      execute_script("arguments[0].value = 500000; arguments[0].dispatchEvent(new Event('input'))", mortgage_slider)
    end

    # Submit property details
    click_on "Next: Income & Loan Options"
    
    # Step 4: Verify we're on income and loan page
    assert_current_path(/income_and_loan/)
    assert_selector "h1", text: "Income & Loan Options"
    assert_selector ".step-item.active", text: "3"

    # Verify property summary is displayed
    assert_text "$2,000,000"  # Property value
    assert_text "Individual"  # Ownership
    assert_text "Primary Residence"  # Property type
    assert_text "$500,000"   # Existing mortgage

    # Step 5: Configure loan options
    within(".application-form") do
      # Set loan term
      loan_slider = find('input[type="range"][name="application[loan_term]"]')
      execute_script("arguments[0].value = 25; arguments[0].dispatchEvent(new Event('input'))", loan_slider)
      
      # Set income payout term  
      income_slider = find('input[type="range"][name="application[income_payout_term]"]')
      execute_script("arguments[0].value = 20; arguments[0].dispatchEvent(new Event('input'))", income_slider)
      
      # Wait for mortgage cards to load
      assert_selector ".mortgage-type-cards"
      
      # Verify both mortgage options are available
      assert_text "Interest Only"
      assert_text "Principal and Interest"
      assert_text "Recommended"  # Principal & Interest should be marked as recommended
      
      # Select Principal and Interest (should be pre-selected)
      find(".mortgage-card", text: "Principal and Interest").click
      
      # Select growth rate
      click_on "Medium (4%)"
    end
    
    # Submit income and loan options
    click_on "Continue to Pre-approval"
    
    # Step 6: Verify we're on summary page
    assert_current_path(/summary/)
    assert_selector "h1", text: "Pre-approval Summary"
    assert_selector ".step-item.active", text: "4"
    
    # Verify application summary details
    assert_text "$2,000,000"     # Property value
    assert_text "Individual"      # Ownership
    assert_text "Primary Residence"  # Property type
    assert_text "$500,000"       # Existing mortgage
    assert_text "25 years"       # Loan term
    assert_text "20 years"       # Income payout term
    assert_text "Principal and Interest"  # Mortgage type
    assert_text "4%"             # Growth rate
    
    # Verify calculations are displayed
    assert_selector ".income-amount"      # Monthly income
    assert_selector ".equity-preserved"   # Equity preserved
    
    # Step 7: Submit application
    click_on "Submit Application"
    
    # Verify we're on congratulations page
    assert_current_path(/congratulations/)
    assert_selector "h1", text: /congratulations|success/i
    
    # Verify application was created and submitted
    application = @user.applications.last
    assert_not_nil application
    assert_equal "submitted", application.status
    assert_equal 2000000, application.home_value
    assert_equal "individual", application.ownership_status
    assert_equal 25, application.loan_term
    assert_equal 20, application.income_payout_term
    assert_not_nil application.mortgage_id
    assert_equal 4.0, application.growth_rate
  end

  test "complete application process with joint ownership" do
    sign_in @user
    visit new_application_path

    within(".application-form") do
      # Set basic details
      slider = find('input[type="range"][name="application[home_value]"]')
      execute_script("arguments[0].value = 1500000; arguments[0].dispatchEvent(new Event('input'))", slider)
      
      # Select joint ownership
      select "Joint Ownership", from: "application[ownership_status]"
      select "Investment Property", from: "application[property_state]"
      
      # Wait for joint ownership fields to appear
      assert_selector('[data-application-form-target="jointFields"]', visible: true)
      
      # Fill in borrower details
      fill_in "borrower_name_1", with: "John Smith"
      fill_in "borrower_name_2", with: "Jane Smith"
      
      # Set ages using the joint sliders
      first_age_slider = find('input[name="borrower_age_1"]')
      execute_script("arguments[0].value = 45; arguments[0].dispatchEvent(new Event('input'))", first_age_slider)
      
      second_age_slider = find('input[name="borrower_age_2"]')
      execute_script("arguments[0].value = 42; arguments[0].dispatchEvent(new Event('input'))", second_age_slider)
    end

    click_on "Next: Income & Loan Options"
    
    # Verify joint ownership is displayed in summary
    assert_text "Joint Ownership"
    assert_text "Investment Property"
    
    # Continue through the process
    within(".application-form") do
      # Select Interest Only mortgage this time
      find(".mortgage-card", text: "Interest Only").click
      
      # Select high growth rate
      click_on "High (7%)"
    end
    
    click_on "Continue to Pre-approval"
    
    # Verify joint ownership details in summary
    assert_text "Joint Ownership"
    assert_text "Interest Only"
    assert_text "7%"
    
    click_on "Submit Application"
    assert_current_path(/congratulations/)
    
    # Verify application data
    application = @user.applications.last
    assert_equal "joint", application.ownership_status
    assert_equal "investment", application.property_state
    assert application.borrower_names.present?
    assert_equal 7.0, application.growth_rate
  end

  test "complete application process with lender ownership" do
    sign_in @user
    visit new_application_path

    within(".application-form") do
      slider = find('input[type="range"][name="application[home_value]"]')
      execute_script("arguments[0].value = 3000000; arguments[0].dispatchEvent(new Event('input'))", slider)
      
      # Select lender ownership
      select "Lender", from: "application[ownership_status]"
      select "Holiday Home", from: "application[property_state]"
      
      # Wait for lender fields to appear and fill company name
      assert_selector('[data-application-form-target="lenderFields"]', visible: true)
      fill_in "application[company_name]", with: "Test Lending Corp"
    end

    click_on "Next: Income & Loan Options"
    assert_text "Lender"
    assert_text "Holiday Home"
    
    # Complete the process
    within(".application-form") do
      find(".mortgage-card", text: "Principal and Interest").click
      click_on "Low (2%)"
    end
    
    click_on "Continue to Pre-approval"
    
    # Verify lender name appears in summary
    assert_text "Lender"
    assert_text "Test Lending Corp"  # This should now work with our fix
    
    click_on "Submit Application"
    assert_current_path(/congratulations/)
    
    application = @user.applications.last
    assert_equal "lender", application.ownership_status
    assert_equal "Test Lending Corp", application.company_name
  end

  test "complete application process with superannuation fund ownership" do
    sign_in @user
    visit new_application_path

    within(".application-form") do
      slider = find('input[type="range"][name="application[home_value]"]')
      execute_script("arguments[0].value = 2500000; arguments[0].dispatchEvent(new Event('input'))", slider)
      
      # Select super fund ownership
      select "Superannuation Fund", from: "application[property_state]"
      select "Superannuation Fund", from: "application[ownership_status]"
      
      # Wait for super fund fields and fill name
      assert_selector('[data-application-form-target="superFields"]', visible: true)
      fill_in "application[super_fund_name]", with: "Smith Family SMSF"
    end

    click_on "Next: Income & Loan Options"
    assert_text "Superannuation Fund"
    
    # Complete the process
    within(".application-form") do
      find(".mortgage-card", text: "Interest Only").click
      click_on "Custom"
      
      # Use custom growth rate
      custom_slider = find('[data-income-loan-form-target="customRateSlider"]')
      execute_script("arguments[0].value = 3.5; arguments[0].dispatchEvent(new Event('input'))", custom_slider)
    end
    
    click_on "Continue to Pre-approval"
    
    # Verify super fund details
    assert_text "Superannuation Fund"
    assert_text "Smith Family SMSF"
    assert_text "3.5%"
    
    click_on "Submit Application"
    assert_current_path(/congratulations/)
    
    application = @user.applications.last
    assert_equal "super", application.ownership_status
    assert_equal "Smith Family SMSF", application.super_fund_name
    assert_equal 3.5, application.growth_rate
  end

  test "application validation errors are displayed correctly" do
    sign_in @user
    visit new_application_path

    # Try to submit without filling required fields
    click_on "Next: Income & Loan Options"
    
    # Should still be on the same page with errors
    assert_current_path new_application_path
    
    # Error messages should be displayed
    assert_selector ".error-messages, .alert-danger", visible: true
  end

  test "mortgage selection updates income calculations" do
    sign_in @user
    visit new_application_path
    
    # Fill basic details
    within(".application-form") do
      slider = find('input[type="range"][name="application[home_value]"]')
      execute_script("arguments[0].value = 2000000; arguments[0].dispatchEvent(new Event('input'))", slider)
      select "Individual", from: "application[ownership_status]"
      select "Primary Residence", from: "application[property_state]"
    end

    click_on "Next: Income & Loan Options"
    
    # Verify mortgage options display different income amounts
    within(".mortgage-type-cards") do
      assert_selector ".mortgage-card", count: 2
      
      # Both should show income calculations
      assert_selector ".income-amount", minimum: 2
      
      # Click between mortgage types and verify calculations update
      find(".mortgage-card", text: "Interest Only").click
      sleep(1)  # Allow time for calculation
      
      find(".mortgage-card", text: "Principal and Interest").click  
      sleep(1)  # Allow time for calculation
      
      # Verify calculations are present (specific values depend on FPCalculator)
      assert_selector ".income-amount", text: /\$[\d,]+/
    end
  end

  test "growth rate selection updates property value calculations" do
    sign_in @user
    visit new_application_path
    
    # Complete property details
    within(".application-form") do
      slider = find('input[type="range"][name="application[home_value]"]')
      execute_script("arguments[0].value = 1000000; arguments[0].dispatchEvent(new Event('input'))", slider)
      select "Individual", from: "application[ownership_status]"
      select "Primary Residence", from: "application[property_state]"
    end

    click_on "Next: Income & Loan Options"
    
    # Test different growth rates
    within(".property-appreciation-section") do
      click_on "Low (2%)"
      sleep(1)
      assert_selector '[data-income-loan-form-target="estimatedPropertyValue"]'
      
      click_on "High (7%)"
      sleep(1)
      assert_selector '[data-income-loan-form-target="estimatedPropertyValue"]'
      
      # Test custom rate
      click_on "Custom"
      assert_selector '[data-income-loan-form-target="customRateInput"]', visible: true
      
      custom_slider = find('[data-income-loan-form-target="customRateSlider"]')
      execute_script("arguments[0].value = 5.5; arguments[0].dispatchEvent(new Event('input'))", custom_slider)
      
      assert_text "5.5%"
    end
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_on "Sign in"
  end
end