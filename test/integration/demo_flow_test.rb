require "test_helper"

class DemoFlowTest < ActionDispatch::IntegrationTest
  # ====================================================
  # New Webapp-style Demo Flow Tests
  # ====================================================

  test "demo property search page is accessible without authentication" do
    get demo_applications_path
    assert_response :success
    assert_select "h1.demo-section-title", text: "Calculate in minutes"
    assert_select ".demo-step-card-v2", count: 3
    assert_select ".demo-property-card-v2", count: 1
    assert_select ".demo-continue-btn", text: /Continue with this property/
  end

  test "demo property details page is accessible without authentication" do
    get demo_property_details_applications_path
    assert_response :success
    assert_select "h1.demo-section-title-numbered", text: "1. Property details"
    assert_select ".demo-property-card-v2", count: 1
    assert_select ".demo-projected-value-card", count: 1
  end

  test "demo mortgage details page is accessible without authentication" do
    get demo_mortgage_details_applications_path
    assert_response :success
    assert_select "h1.demo-section-title-numbered", text: "2. Set income and mortgage options"
    assert_select ".demo-property-card-v2", count: 1
    assert_select ".demo-mortgage-option-card", count: 2
  end

  test "demo funding details page is accessible without authentication" do
    get demo_funding_details_applications_path
    assert_response :success
    assert_select "h1.demo-section-title-numbered", text: "3. Funding details"
    assert_select ".demo-summary-card", count: 1
  end

  test "demo preapproved page shows congratulations with happy man image" do
    get demo_preapproved_applications_path
    assert_response :success
    assert_select ".demo-preapproved-page", count: 1
    assert_select "h1.demo-preapproved-title", text: "Congratulations!"
    # Check for happy man image
    assert_select "img[src*='bg-man-with-phone']", count: 1
  end

  test "demo flow has correct navigation between pages" do
    # Step 1: Property Search (US default)
    get demo_applications_path
    assert_response :success
    # Link includes market parameter
    assert_select "a[href*='demo_property_details']", minimum: 1

    # Step 2: Property Details
    get demo_property_details_applications_path
    assert_response :success
    assert_select "a[href*='demo_mortgage_details']", count: 1

    # Step 3: Mortgage Details
    get demo_mortgage_details_applications_path
    assert_response :success
    assert_select "a[href*='demo_funding_details']", count: 1

    # Step 4: Funding Details
    get demo_funding_details_applications_path
    assert_response :success
    assert_select "a[href*='demo_preapproved']", count: 1

    # Step 5: Pre-Approved
    get demo_preapproved_applications_path
    assert_response :success
    # Page renders successfully (CTA section is currently commented out)
    assert_select ".demo-preapproved-title", text: "Congratulations!"
  end

  test "get_started page links to demo SPA instead of email modal" do
    get get_started_path
    assert_response :success
    # Calculate buttons should link to demo SPA (with market param)
    assert_select "a[href*='applications/demo_spa']", minimum: 1
    # Should NOT have email modal open actions
    assert_select "[data-action*='openEmailModal']", count: 0
  end

  # ====================================================
  # Legacy Demo Routes - Test Redirects
  # ====================================================

  test "legacy demo_income_loan redirects to demo_mortgage_details" do
    get demo_income_loan_applications_path
    assert_redirected_to demo_mortgage_details_applications_path
  end

  test "legacy demo_summary redirects to demo_funding_details" do
    get demo_summary_applications_path
    assert_redirected_to demo_funding_details_applications_path
  end

  # ====================================================
  # Demo SPA Tests - Single Page Application
  # ====================================================

  test "demo SPA page is accessible without authentication" do
    get demo_spa_applications_path
    assert_response :success
    # Landing step content
    assert_select "h1.demo-section-title", text: "Calculate in minutes"
    # All steps are present in the DOM
    assert_select ".demo-step", count: 5
    # Progress bar elements
    assert_select ".demo-spa-progress-step", count: 3
    assert_select ".demo-spa-progress-line", count: 2
  end

  test "demo SPA contains all step content" do
    get demo_spa_applications_path
    assert_response :success

    # Step 0: Landing
    assert_select ".demo-step-cards-v2", count: 1
    assert_select ".demo-step-card-v2", count: 3

    # Step 1: Property Details
    assert_select ".demo-projected-value-card", count: 1
    assert_select "[data-growth-rate]", minimum: 3

    # Step 2: Mortgage Details
    assert_select ".demo-mortgage-option-card", count: 2
    assert_select ".demo-slider", count: 1

    # Step 3: Funding Summary
    assert_select ".demo-summary-card", count: 1
    assert_select ".demo-summary-section", count: 4

    # Step 4: Congratulations
    assert_select ".demo-preapproved-title", text: "Congratulations!"
    assert_select "img[src*='bg-man-with-phone']", count: 1
  end

  test "demo SPA works with Australian market parameter" do
    get demo_spa_applications_path(market: 'au')
    assert_response :success
    # Check AU property address is shown
    assert_select ".demo-property-card-address", text: /Scotland Island/
  end

  test "demo SPA works with US market parameter" do
    get demo_spa_applications_path(market: 'us')
    assert_response :success
    # Check US property address is shown
    assert_select ".demo-property-card-address", text: /Laguna Beach/
  end

  test "demo SPA has Stimulus controller attributes" do
    get demo_spa_applications_path
    assert_response :success
    # Main container has demo-spa controller
    assert_select "[data-controller*='demo-spa']", count: 1
    # Step navigation buttons exist
    assert_select "[data-action*='demo-spa#goToStep']", minimum: 4
  end
end
