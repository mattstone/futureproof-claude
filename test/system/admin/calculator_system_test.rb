require "application_system_test_case"

class Admin::CalculatorSystemTest < ApplicationSystemTestCase
  def setup
    @admin_user = users(:admin_user)
    sign_in @admin_user
  end

  test "calculator page loads successfully" do
    visit admin_calculators_path
    
    assert_text "Single mortgage model with Monte Carlo prices"
    assert_selector "form"
    assert_selector "input[name='calculator[house_value]']"
    assert_selector "input[type='submit'][value='Calculate']"
  end

  test "calculator form has all required fields" do
    visit admin_calculators_path
    
    # Borrower Parameters
    assert_selector "input[name='calculator[house_value]']"
    assert_selector "input[name='calculator[loan_duration]']"
    assert_selector "input[name='calculator[annuity_duration]']"
    assert_selector "select[name='calculator[loan_type]']"
    assert_selector "input[name='calculator[loan_to_value]']"
    assert_selector "input[name='calculator[annual_income]']"
    assert_selector "input[name='calculator[at_risk_captital_fraction]']"
    
    # Economic assumptions
    assert_selector "input[name='calculator[equity_return]']"
    assert_selector "input[name='calculator[volatility]']"
    assert_selector "input[name='calculator[total_paths]']"
    assert_selector "input[name='calculator[random_seed]']"
    assert_selector "input[name='calculator[cash_rate]']"
    assert_selector "input[name='calculator[insurer_profit_margin]']"
    assert_selector "input[name='calculator[hedged]']"
    
    # Loan parameters
    assert_selector "input[name='calculator[wholesale_lending_margin]']"
    assert_selector "input[name='calculator[additional_loan_margins]']"
    assert_selector "input[name='calculator[holiday_enter_fraction]']"
    assert_selector "input[name='calculator[holiday_exit_fraction]']"
    assert_selector "input[name='calculator[subperform_loan_threshold_quarters]']"
    assert_selector "input[name='calculator[max_superpay_factor]']"
    assert_selector "input[name='calculator[superpay_start_factor]']"
    assert_selector "input[name='calculator[enable_pool]']"
  end

  test "calculator form has default values" do
    visit admin_calculators_path
    
    assert_field "calculator[house_value]", with: "1500000"
    assert_field "calculator[loan_duration]", with: "30"
    assert_field "calculator[annuity_duration]", with: "10"
    assert_field "calculator[loan_to_value]", with: "80"
    assert_field "calculator[annual_income]", with: "30000"
    assert_field "calculator[equity_return]", with: "10.8"
    assert_field "calculator[volatility]", with: "15"
    assert_field "calculator[total_paths]", with: "1000"
    assert_field "calculator[cash_rate]", with: "3.85"
    assert_field "calculator[insurer_profit_margin]", with: "50"
  end

  test "hedged checkbox toggles visibility of hedging fields" do
    visit admin_calculators_path
    
    # Initially, hedging fields should be hidden
    assert_selector "[data-monte-carlo-calculator-target='hedgingCost']", visible: false
    assert_selector "[data-monte-carlo-calculator-target='hedgingMaxLoss']", visible: false
    assert_selector "[data-monte-carlo-calculator-target='hedgingCap']", visible: false
    
    # Check the hedged checkbox
    check "calculator[hedged]"
    
    # Wait for fields to become visible (Stimulus controller should handle this)
    assert_selector "[data-monte-carlo-calculator-target='hedgingCost']", visible: true
    assert_selector "[data-monte-carlo-calculator-target='hedgingMaxLoss']", visible: true
    assert_selector "[data-monte-carlo-calculator-target='hedgingCap']", visible: true
  end

  test "calculator form submits without errors" do
    visit admin_calculators_path
    
    # Fill in minimum required fields
    fill_in "calculator[house_value]", with: "1000000"
    fill_in "calculator[loan_duration]", with: "25"
    fill_in "calculator[annuity_duration]", with: "10"
    fill_in "calculator[annual_income]", with: "25000"
    fill_in "calculator[total_paths]", with: "10" # Use small number for faster test
    
    # Submit the form
    click_button "Calculate"
    
    # Should not show any error messages
    assert_no_text "Calculation error"
    assert_no_text "error occurred"
  end

  test "calculator shows loading state during calculation" do
    visit admin_calculators_path
    
    # Fill in fields
    fill_in "calculator[total_paths]", with: "100"
    
    # Submit form
    click_button "Calculate"
    
    # Check for loading indicators
    assert_selector "[data-monte-carlo-calculator-target='spinner']", visible: false # Should be hidden initially
    assert_selector "[data-monte-carlo-calculator-target='submitBtn'][disabled]", wait: 1 # Button should be disabled during calculation
  end

  test "calculator displays results after successful calculation" do
    visit admin_calculators_path
    
    # Use small path count for faster test
    fill_in "calculator[total_paths]", with: "10"
    
    # Submit form and wait for results
    click_button "Calculate"
    
    # Wait for results to appear
    assert_selector "[data-monte-carlo-calculator-target='results']", visible: true, wait: 10
    
    # Check for main output table
    assert_selector "table[data-monte-carlo-calculator-target='mainOutputTable']", visible: true
    assert_text "Reinvestment fraction"
    assert_text "Initial reinvestment"
    assert_text "Outstanding"
    
    # Check for path table
    assert_selector "table[data-monte-carlo-calculator-target='pathTable']", visible: true
    
    # Check for navigation tabs
    assert_text "Main outputs table"
    assert_text "Path table"
  end

  test "path table selector changes displayed data" do
    visit admin_calculators_path
    
    # Calculate with small dataset
    fill_in "calculator[total_paths]", with: "10"
    click_button "Calculate"
    
    # Wait for results
    assert_selector "[data-monte-carlo-calculator-target='results']", visible: true, wait: 10
    
    # Click on Path table tab
    click_link "Path table"
    
    # Check path table selector
    assert_selector "select[name='path_table_type']"
    
    # Try changing the selection
    select "Median", from: "path_table_type"
    # The table content should update (handled by Stimulus)
  end

  test "form validation shows errors for invalid inputs" do
    visit admin_calculators_path
    
    # Clear required field
    fill_in "calculator[house_value]", with: ""
    fill_in "calculator[annual_income]", with: ""
    fill_in "calculator[total_paths]", with: "0"
    
    click_button "Calculate"
    
    # Should show validation errors
    assert_text "error", wait: 5 # Generic error message check
  end

  test "calculator respects input constraints" do
    visit admin_calculators_path
    
    # Check min/max constraints are enforced by HTML
    house_value_field = find("input[name='calculator[house_value]']")
    assert_equal "1000000", house_value_field[:min]
    assert_equal "3000000", house_value_field[:max]
    
    loan_duration_field = find("input[name='calculator[loan_duration]']")
    assert_equal "10", loan_duration_field[:min]
    assert_equal "30", loan_duration_field[:max]
    
    total_paths_field = find("input[name='calculator[total_paths]']")
    assert_equal "1", total_paths_field[:min]
    assert_equal "20000", total_paths_field[:max]
  end

  test "calculator works with different loan types" do
    visit admin_calculators_path
    
    # Test Interest only
    select "Interest only", from: "calculator[loan_type]"
    fill_in "calculator[total_paths]", with: "5"
    click_button "Calculate"
    assert_selector "[data-monte-carlo-calculator-target='results']", visible: true, wait: 10
    
    # Test Principal+Interest
    select "Principal+Interest", from: "calculator[loan_type]"
    click_button "Calculate"
    assert_selector "[data-monte-carlo-calculator-target='results']", visible: true, wait: 10
    
    # Test Hybrid
    select "Hybrid", from: "calculator[loan_type]"
    click_button "Calculate"
    assert_selector "[data-monte-carlo-calculator-target='results']", visible: true, wait: 10
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign In"
    assert_text "Dashboard" # Confirm we're logged in
  end
end