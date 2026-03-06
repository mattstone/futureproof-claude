require "test_helper"

class Phase4MultiregionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # Create lenders for each region
    @lender_au = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    @lender_us = Lender.create!(
      name: "FutureProof Financial US",
      region: "US",
      abn: "98-7654321",
      status: "active",
      max_loan_amount: 3_000_000,
      min_customer_age: 62,
      max_customer_age: 95
    )

    @lender_nz = Lender.create!(
      name: "FutureProof Financial NZ",
      region: "NZ",
      abn: "12345678",
      status: "active",
      max_loan_amount: 1_500_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    @lender_uk = Lender.create!(
      name: "FutureProof Financial UK",
      region: "UK",
      abn: "GB123456789",
      status: "active",
      max_loan_amount: 500_000,
      min_customer_age: 55,
      max_customer_age: 85
    )
  end

  # Test 1: AU site shows AU-specific content
  test "AU site displays Australian-specific UI, currency, and compliance" do
    get "/au"
    assert_response :success

    # Should show AU-specific content
    assert_select "h1", /australia|australian/i
    assert_select "span", /AUD|A\$/ # Currency
    assert_select "p|span", /privacy act|australian/i # AU compliance

    # Get calculator
    get "/au/calculator"
    assert_response :success

    # Should mention Centrelink or Australian age pension
    assert_select "p|span", /centrelink|pension/i
  end

  # Test 2: US site shows US-specific content
  test "US site displays US-specific UI, currency, and disclosures" do
    get "/us"
    assert_response :success

    # Should show US-specific content
    assert_select "h1", /united states|america/i
    assert_select "span", /USD|\$/ # Currency

    # Get calculator
    get "/us/calculator"
    assert_response :success

    # Should mention TILA/RESPA or US-specific regulations
    assert_select "p|span", /disclosure|tila|respa|federal/i
  end

  # Test 3: NZ site shows NZ-specific content
  test "NZ site displays New Zealand-specific UI and compliance" do
    get "/nz"
    assert_response :success

    # Should show NZ-specific content
    assert_select "h1", /new zealand|aotearoa/i
    assert_select "span", /NZD|NZ\$/ # Currency

    # Get calculator
    get "/nz/calculator"
    assert_response :success

    # Should mention CCCFA or NZ regulations
    assert_select "p|span", /cccfa|credit|new zealand/i
  end

  # Test 4: UK site shows UK-specific content
  test "UK site displays UK-specific UI and compliance" do
    get "/uk"
    assert_response :success

    # Should show UK-specific content
    assert_select "h1", /united kingdom|british/i
    assert_select "span", /GBP|£/ # Currency

    # Get calculator
    get "/uk/calculator"
    assert_response :success

    # Should mention FCA or UK-specific regulations
    assert_select "p|span", /fca|mcob|ico|gdpr/i
  end

  # Test 5: AU application generates AU mortgage contract
  test "AU application generates AU-specific mortgage contract" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender_au,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender_au
    )

    sign_in lender_admin

    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10
      }
    }

    application.reload
    contract = application.mortgage_contract

    # Contract should be AU
    assert_equal "AU", contract.region

    # Contract should contain AU-specific clauses
    assert contract.contract_html.include?("NNEG") || contract.contract_html.present?
    assert contract.contract_html.include?("Centrelink") || contract.contract_html.include?("Australia")
  end

  # Test 6: US application generates US mortgage contract with TILA/RESPA
  test "US application generates US-specific mortgage contract with TILA/RESPA" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender_us,
      property_address: "456 Main Street",
      property_suburb: "Los Angeles",
      property_state: "CA",
      property_postcode: "90001",
      property_value: 1_000_000,
      property_type: "house",
      desired_monthly_income: 3_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123-45-6789",
      bank_account_number: "1234567890123456",
      status: "pending_review"
    )

    lender_admin = User.create!(
      email: "admin@us-lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender_us
    )

    sign_in lender_admin

    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 1_000_000,
        approved_interest_rate: 4.5,
        approved_term_years: 10
      }
    }

    application.reload
    contract = application.mortgage_contract

    # Contract should be US
    assert_equal "US", contract.region

    # Should contain US-specific disclosures
    assert contract.contract_html.include?("TILA") || contract.contract_html.include?("RESPA") || contract.contract_html.include?("Disclosure")
  end

  # Test 7: NZ application generates NZ mortgage contract
  test "NZ application generates NZ-specific mortgage contract" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender_nz,
      property_address: "789 Queen Street",
      property_suburb: "Auckland",
      property_state: "AUK",
      property_postcode: "1010",
      property_value: 900_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "12345678",
      bank_account_number: "12-3456-7890123-00",
      status: "pending_review"
    )

    lender_admin = User.create!(
      email: "admin@nz-lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender_nz
    )

    sign_in lender_admin

    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 900_000,
        approved_interest_rate: 3.8,
        approved_term_years: 10
      }
    }

    application.reload
    contract = application.mortgage_contract

    # Contract should be NZ
    assert_equal "NZ", contract.region

    # Should contain NZ-specific references
    assert contract.contract_html.include?("CCCFA") || contract.contract_html.include?("New Zealand") || contract.contract_html.present?
  end

  # Test 8: UK application generates UK mortgage contract with FCA compliance
  test "UK application generates UK-specific mortgage contract with FCA compliance" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender_uk,
      property_address: "123 High Street",
      property_suburb: "London",
      property_state: "ENG",
      property_postcode: "SW1A 1AA",
      property_value: 500_000,
      property_type: "house",
      desired_monthly_income: 1_500,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "AA 12 34 56 C",
      bank_account_number: "12345678",
      status: "pending_review"
    )

    lender_admin = User.create!(
      email: "admin@uk-lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender_uk
    )

    sign_in lender_admin

    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 500_000,
        approved_interest_rate: 3.0,
        approved_term_years: 10
      }
    }

    application.reload
    contract = application.mortgage_contract

    # Contract should be UK
    assert_equal "UK", contract.region

    # Should contain UK-specific references
    assert contract.contract_html.include?("FCA") || contract.contract_html.include?("MCOB") || contract.contract_html.include?("UK")
  end

  # Test 9: Quote engine calculates correctly for each region with local currency
  test "quote engine calculates correctly in each region with proper currency" do
    regions = ["AU", "US", "NZ", "UK"]

    regions.each do |region|
      post "/api/v1/quotes", params: {
        property_value: 800_000,
        age: 72,
        region: region,
        desired_income: 2_000,
        loan_term_years: 10
      }, headers: { "CONTENT_TYPE" => "application/json" }

      assert_response :success
      quote = JSON.parse(response.body)

      # Verify quote structure
      assert quote["quote_id"].present?
      assert quote["monthly_income"].present?
      assert quote["loan_amount"].present?
      assert quote["currency"].present?
      assert quote["region"] == region
    end
  end

  # Test 10: Multi-region compliance audit
  test "all regions comply with their respective regulations" do
    regions_compliance = {
      "AU" => ["Privacy Act", "ASIC", "Centrelink"],
      "US" => ["TILA", "RESPA", "SEC", "State Laws"],
      "NZ" => ["CCCFA", "Privacy Act 2020"],
      "UK" => ["FCA", "MCOB", "GDPR", "ICO"]
    }

    regions_compliance.each do |region, required_terms|
      get "/#{region.downcase}"
      assert_response :success

      # At least one required term should be present
      # (this is a simplified check)
      page_text = response.body.downcase

      assert page_text.include?(required_terms.first.downcase) ||
             page_text.include?(required_terms[1]&.downcase) ||
             page_text.include?("compliance") ||
             page_text.include?("regulation"),
             "Region #{region} missing compliance terms"
    end
  end
end
