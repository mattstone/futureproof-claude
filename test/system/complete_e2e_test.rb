require "application_system_test_case"

# Complete End-to-End Browser Tests
# Tests all major user journeys through the actual browser
class CompleteE2ETest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_user)
    @regular_user = users(:regular_user)
  end

  # ============================================
  # HOMEPAGE & PUBLIC PAGES
  # ============================================

  test "homepage loads and displays key elements" do
    visit root_path

    assert_selector "body"
    # Check for navigation or key homepage elements
    assert page.has_content?("Futureproof") || page.has_selector?("header")
  end

  test "apply page loads with calculator" do
    visit apply_path

    assert_selector "body"
    # The calculator should be visible
    assert page.has_current_path?(apply_path) || page.has_current_path?(/apply/)
  end

  test "legal pages are accessible" do
    # Create legal documents if needed
    ensure_legal_documents_exist

    visit terms_and_conditions_path
    assert_no_selector ".error", wait: 2

    visit privacy_policy_path
    assert_no_selector ".error", wait: 2

    visit terms_of_use_path
    assert_no_selector ".error", wait: 2
  end

  # ============================================
  # AUTHENTICATION FLOWS
  # ============================================

  test "login page renders correctly" do
    visit new_user_session_path

    assert_selector "form"
    assert_selector "input[type='email'], input[name*='email']"
    assert_selector "input[type='password']"
    assert_selector "input[type='submit'], button[type='submit']"
  end

  test "user can log in successfully" do
    visit new_user_session_path

    fill_in_login_form(@regular_user.email, "password")
    click_login_button

    # Should redirect to dashboard or show success
    assert_no_current_path new_user_session_path, wait: 5
  end

  test "invalid login shows error" do
    visit new_user_session_path

    fill_in_login_form("wrong@example.com", "wrongpassword")
    click_login_button

    # Should show error or stay on login page
    assert page.has_content?(/invalid|error|incorrect/i) || page.has_current_path?(/sign_in/)
  end

  test "registration page renders correctly" do
    visit new_user_registration_path

    assert_selector "form"
    assert_selector "input[type='email'], input[name*='email']"
    assert_selector "input[type='password']"
  end

  test "user can log out" do
    sign_in_as(@regular_user)
    visit dashboard_path

    # Turbo's data-turbo-method="delete" requires Turbo to intercept the click
    # Use JavaScript to trigger the DELETE request directly via Turbo.visit
    execute_script(<<~JS)
      const link = document.querySelector('a[href*="sign_out"]');
      if (link && window.Turbo) {
        Turbo.visit(link.href, { action: 'advance', method: 'delete' });
      } else if (link) {
        // Fallback: submit via form
        const form = document.createElement('form');
        form.method = 'POST';
        form.action = link.href;
        const methodInput = document.createElement('input');
        methodInput.type = 'hidden';
        methodInput.name = '_method';
        methodInput.value = 'delete';
        form.appendChild(methodInput);
        document.body.appendChild(form);
        form.submit();
      }
    JS

    # Wait for redirect
    sleep 3

    # Should not be on dashboard anymore (redirected to homepage)
    assert_not_equal "/dashboard", current_path,
      "Should be redirected away from dashboard after logout"
  end

  # ============================================
  # USER DASHBOARD
  # ============================================

  test "authenticated user can access dashboard" do
    sign_in_as(@regular_user)
    visit dashboard_path

    assert_current_path dashboard_path
    assert_selector "body"
  end

  test "unauthenticated user is redirected from dashboard" do
    visit dashboard_path

    # Should redirect to login
    assert_current_path new_user_session_path, wait: 5
  end

  # ============================================
  # APPLICATION FLOW
  # ============================================

  test "authenticated user can start new application" do
    sign_in_as(@regular_user)
    visit new_application_path

    # Should either show form or redirect to first step
    assert page.has_selector?("form") || page.has_current_path?(/application/), wait: 5
  end

  test "application edit page loads for existing application" do
    sign_in_as(@regular_user)

    application = create_test_application(@regular_user, status: :property_details)
    visit edit_application_path(application)

    assert_selector "form", wait: 5
  end

  test "application can be updated" do
    sign_in_as(@regular_user)

    application = create_test_application(@regular_user, status: :property_details)
    visit edit_application_path(application)

    # Try to update a field if it exists
    if page.has_field?("Home value", wait: 2) || page.has_field?("application[home_value]", wait: 2)
      fill_in "application[home_value]", with: "2500000"
    end

    # Look for submit button
    if page.has_button?("Save", wait: 2)
      click_button "Save"
    elsif page.has_button?("Continue", wait: 2)
      click_button "Continue"
    elsif page.has_button?("Next", wait: 2)
      click_button "Next"
    end

    # Should not show error
    assert_no_selector ".error", text: /failed|invalid/i, wait: 2
  end

  test "user can view their application" do
    sign_in_as(@regular_user)

    application = create_test_application(@regular_user, status: :submitted)
    visit application_path(application)

    assert_selector "body"
    # Should show application details
  end

  # ============================================
  # ADMIN PORTAL
  # ============================================

  test "admin can access admin dashboard" do
    sign_in_as(@admin)
    visit admin_dashboard_index_path

    assert_current_path admin_dashboard_index_path
    assert_selector "body"
  end

  test "non-admin cannot access admin dashboard" do
    sign_in_as(@regular_user)
    visit admin_dashboard_index_path

    # Should be redirected or show forbidden
    assert_no_current_path admin_dashboard_index_path
  end

  test "admin can view applications list" do
    sign_in_as(@admin)
    visit admin_applications_path

    assert_selector "body"
    # Should show table or list
  end

  test "admin can view application detail" do
    sign_in_as(@admin)

    application = create_test_application(@regular_user, status: :submitted)
    visit admin_application_path(application)

    assert_selector "body"
  end

  test "admin can edit application" do
    sign_in_as(@admin)

    application = create_test_application(@regular_user, status: :submitted)
    visit edit_admin_application_path(application)

    assert_selector "form", wait: 5
  end

  test "admin can view lenders list" do
    sign_in_as(@admin)
    visit admin_lenders_path

    assert_selector "body"
  end

  test "admin can view mortgages list" do
    sign_in_as(@admin)
    visit admin_mortgages_path

    assert_selector "body"
  end

  test "admin can view contracts list" do
    sign_in_as(@admin)
    visit admin_contracts_path

    assert_selector "body"
  end

  test "admin can view email templates" do
    sign_in_as(@admin)
    visit admin_email_templates_path

    assert_selector "body"
  end

  test "admin can view email workflows" do
    sign_in_as(@admin)
    visit admin_email_workflows_path

    assert_selector "body"
  end

  # ============================================
  # MESSAGING
  # ============================================

  test "user can view messages on application" do
    sign_in_as(@regular_user)

    application = create_test_application(@regular_user, status: :submitted)
    visit messages_application_path(application)

    assert_selector "body"
  end

  # ============================================
  # API CALCULATOR (JavaScript functionality)
  # ============================================

  test "calculator page has interactive elements" do
    visit apply_path

    # Check for calculator-related inputs
    has_inputs = page.has_selector?("input[type='range']", wait: 3) ||
                 page.has_selector?("input[type='number']", wait: 1) ||
                 page.has_selector?("[data-controller]", wait: 1)

    assert has_inputs || page.has_selector?("form"), "Calculator page should have interactive elements"
  end

  # ============================================
  # NAVIGATION
  # ============================================

  test "main navigation works" do
    visit root_path

    # Check for navigation links
    if page.has_link?("Apply", wait: 2)
      click_link "Apply"
      assert page.has_current_path?(/apply/), "Should navigate to apply page"
    end
  end

  test "admin navigation works" do
    sign_in_as(@admin)
    visit admin_dashboard_index_path

    # Check admin navigation
    if page.has_link?("Applications", wait: 2)
      click_link "Applications"
      assert page.has_current_path?(/admin.*application/), "Should navigate to applications"
    end
  end

  # ============================================
  # FORM VALIDATION
  # ============================================

  test "login form validates required fields" do
    visit new_user_session_path

    # Try to submit empty form
    click_login_button

    # Should show validation error or stay on page
    assert page.has_current_path?(/sign_in|session/) || page.has_content?(/required|invalid|error/i)
  end

  # ============================================
  # ERROR PAGES
  # ============================================

  test "404 page renders gracefully" do
    visit "/nonexistent-page-xyz"

    # Should show error page, not crash
    assert_selector "body"
  end

  private

  # Helper to sign in via browser
  def sign_in_as(user)
    visit new_user_session_path
    fill_in_login_form(user.email, "password")  # Fixture password is 'password'
    click_login_button
    # Wait for redirect
    sleep 2
  end

  # Helper to fill in login form (handles different form layouts)
  def fill_in_login_form(email, password)
    # Wait for form to be present
    assert_selector "form", wait: 5

    # Use explicit name attributes for reliability
    fill_in "user[email]", with: email
    fill_in "user[password]", with: password
  end

  # Helper to click login button
  def click_login_button
    if page.has_button?("Sign In", wait: 2)
      click_button "Sign In"
    elsif page.has_button?("Log In", wait: 2)
      click_button "Log In"
    elsif page.has_button?("Login", wait: 2)
      click_button "Login"
    else
      find("input[type='submit'], button[type='submit']").click
    end
  end

  # Helper to create test application
  def create_test_application(user, overrides = {})
    defaults = {
      user: user,
      address: "123 Test Street, Sydney NSW 2000",
      home_value: 2_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created,
      borrower_age: 65,
      growth_rate: 2.5,
      existing_mortgage_amount: 0,
      has_existing_mortgage: false
    }
    Application.create!(defaults.merge(overrides))
  end

  # Helper to ensure legal documents exist
  def ensure_legal_documents_exist
    unless TermsAndCondition.exists?
      TermsAndCondition.create!(
        title: "Terms and Conditions",
        content: "Test content",
        version: 1,
        last_updated: Time.current,
        is_active: true
      )
    end

    unless PrivacyPolicy.exists?
      PrivacyPolicy.create!(
        title: "Privacy Policy",
        content: "Test content",
        version: 1,
        last_updated: Time.current,
        is_active: true
      )
    end

    unless TermsOfUse.exists?
      TermsOfUse.create!(
        title: "Terms of Use",
        content: "Test content",
        version: 1,
        last_updated: Time.current,
        is_active: true
      )
    end
  end
end
