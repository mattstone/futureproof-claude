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
    assert_select "h1.demo-section-title-numbered", text: "2. Set income and loan options"
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

  test "get_started page links to demo instead of email modal" do
    get get_started_path
    assert_response :success
    # Calculate buttons should link to demo
    assert_select "a[href='#{demo_applications_path}']", minimum: 1
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
end
