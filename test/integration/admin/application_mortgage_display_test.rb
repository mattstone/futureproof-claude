require 'test_helper'

class Admin::ApplicationMortgageDisplayTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  
  setup do
    @admin = User.create!(
      email: 'admin@example.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      terms_accepted: true,
      terms_version: 1
    )
    
    @customer = User.create!(
      email: 'john.doe@example.com', 
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      admin: false,
      terms_accepted: true,
      terms_version: 1,
      country_of_residence: 'Australia'
    )
    
    @mortgage = Mortgage.create!(
      name: 'Reverse Mortgage Pro',
      mortgage_type: 'interest_only',
      lvr: 60
    )
    
    # Sign in as admin
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: 'password123'
      }
    }
  end
  
  test "should display mortgage type and monthly income when mortgage is present" do
    application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35,
      mortgage: @mortgage,
      loan_term: 25,
      income_payout_term: 25,
      growth_rate: 3.5
    )
    
    get admin_application_path(application)
    assert_response :success
    
    # Check that mortgage type is displayed with proper styling
    assert_select '.detail-row', text: /Mortgage Type:/ do
      assert_select 'span.admin-badge.admin-badge-secondary', text: /Interest Only/
    end
    
    # Check that monthly income is displayed with proper styling
    assert_select '.detail-row', text: /Monthly Income:/ do
      assert_select 'span.admin-badge.admin-badge-success'
    end
  end
  
  test "should display fallback text when mortgage is not present" do
    application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
      # No mortgage associated
    )
    
    get admin_application_path(application)
    assert_response :success
    
    # Check that mortgage type shows fallback text
    assert_select '.detail-row', text: /Mortgage Type:/ do
      assert_select 'span', text: /Not selected/, style: /color: #6b7280; font-style: italic;/
    end
    
    # Check that monthly income shows fallback text
    assert_select '.detail-row', text: /Monthly Income:/ do
      assert_select 'span', text: /Not calculated/, style: /color: #6b7280; font-style: italic;/
    end
  end
  
  test "should display correct mortgage type for principal and interest" do
    principal_mortgage = Mortgage.create!(
      name: 'Principal & Interest Mortgage',
      mortgage_type: 'principal_and_interest',
      lvr: 70
    )
    
    application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35,
      mortgage: principal_mortgage,
      loan_term: 25,
      income_payout_term: 25,
      growth_rate: 3.5
    )
    
    get admin_application_path(application)
    assert_response :success
    
    # Check that mortgage type displays as "Principal and Interest"
    assert_select '.detail-row', text: /Mortgage Type:/ do
      assert_select 'span.admin-badge.admin-badge-secondary', text: /Principal and Interest/
    end
  end
  
  test "should calculate and display monthly income correctly" do
    application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1000000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35,
      mortgage: @mortgage,
      loan_term: 20,
      income_payout_term: 20,
      growth_rate: 3.0
    )
    
    get admin_application_path(application)
    assert_response :success
    
    # Verify the monthly income amount is calculated and formatted properly
    monthly_income = application.monthly_income_amount
    assert monthly_income > 0, "Monthly income should be calculated as greater than 0"
    
    formatted_income = application.formatted_monthly_income_amount
    assert_select '.detail-row', text: /Monthly Income:/ do
      assert_select 'span.admin-badge.admin-badge-success', text: formatted_income
    end
  end
  
  test "should handle applications with mortgage but no loan terms gracefully" do
    application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35,
      mortgage: @mortgage
      # No loan_term or income_payout_term set
    )
    
    get admin_application_path(application)
    assert_response :success
    
    # Should still show mortgage type
    assert_select '.detail-row', text: /Mortgage Type:/ do
      assert_select 'span.admin-badge.admin-badge-secondary', text: /Interest Only/
    end
    
    # Should show calculated monthly income (even if 0 due to missing terms)
    assert_select '.detail-row', text: /Monthly Income:/ do
      assert_select 'span.admin-badge.admin-badge-success'
    end
  end
end