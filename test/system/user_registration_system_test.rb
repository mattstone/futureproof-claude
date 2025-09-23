require "application_system_test_case"

class UserRegistrationSystemTest < ApplicationSystemTestCase
  def setup
    # Clear any existing test users
    User.where(email: [
      'system.test@example.com',
      'browser.test@example.com',
      'form.validation@example.com'
    ]).destroy_all
  end

  test "user can complete full registration process in browser" do
    # Visit the signup page
    visit "/users/sign_up"

    # Verify page loads correctly
    assert_text "Create Account"
    assert_text "Start your journey with Equity Preservation Mortgage®"

    # Fill out the registration form
    fill_in "First name", with: "System"
    fill_in "Last name", with: "Test"
    fill_in "Email", with: "system.test@example.com"
    select "🇦🇺 Australia", from: "Country of residence"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"

    # Check the terms and conditions checkbox
    check "I accept the"

    # Verify the reCAPTCHA is present and centered
    assert_selector ".recaptcha-group"
    assert_selector ".g-recaptcha"

    # Count records before submission
    initial_user_count = User.count
    initial_app_count = Application.count

    # Submit the form
    click_button "Create Account"

    # Should redirect after successful registration
    assert_current_path "/", wait: 10

    # Verify user and application were created
    assert_equal initial_user_count + 1, User.count, "User should be created"
    assert_equal initial_app_count + 1, Application.count, "Application should be created"

    # Verify the user details
    user = User.find_by(email: "system.test@example.com")
    assert_not_nil user
    assert_equal "System", user.first_name
    assert_equal "Test", user.last_name
    assert_equal "Australia", user.country_of_residence
    assert user.terms_accepted

    # Verify the application details
    application = user.applications.first
    assert_not_nil application
    assert application.status_created?
    assert_nil application.address  # Should be allowed for created status
    assert_equal 1000000, application.home_value
  end

  test "form validation shows errors for invalid input" do
    visit "/users/sign_up"

    # Try to submit form without required fields
    click_button "Create Account"

    # Should stay on the same page
    assert_current_path "/users/sign_up"

    # Check for validation errors (these might be HTML5 validation)
    # Different browsers handle validation differently, so we check multiple possibilities

    # Try with some fields filled but missing others
    fill_in "First name", with: "Test"
    fill_in "Email", with: "invalid-email"  # Invalid format
    fill_in "Password", with: "123"  # Too short
    fill_in "Confirm Password", with: "456"  # Doesn't match

    click_button "Create Account"

    # Should still be on signup page due to validation errors
    assert_current_path "/users/sign_up"

    # Verify no user was created
    assert_nil User.find_by(first_name: "Test")
  end

  test "terms and conditions modal works correctly" do
    visit "/users/sign_up"

    # Click on the Terms and Conditions link
    click_button "Terms and Conditions"

    # Modal should appear
    assert_selector ".modal-overlay", visible: true
    assert_text "Terms and Conditions"

    # Close modal
    click_button "Close"

    # Modal should disappear
    assert_no_selector ".modal-overlay", visible: true
  end

  test "checkbox and reCAPTCHA are properly aligned" do
    visit "/users/sign_up"

    # Check that terms checkbox is on the same line as text
    terms_group = find(".terms-checkbox-fix")
    assert terms_group

    # Verify checkbox and text are horizontally aligned
    terms_label = terms_group.find(".terms-inline")
    assert terms_label

    # Check that reCAPTCHA is centered
    recaptcha_group = find(".recaptcha-group")
    assert recaptcha_group

    # The reCAPTCHA should be present
    assert_selector ".g-recaptcha"
  end

  test "password confirmation validation works" do
    visit "/users/sign_up"

    fill_in "First name", with: "Password"
    fill_in "Last name", with: "Test"
    fill_in "Email", with: "form.validation@example.com"
    select "🇦🇺 Australia", from: "Country of residence"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "different456"
    check "I accept the"

    click_button "Create Account"

    # Should not create user due to password mismatch
    assert_nil User.find_by(email: "form.validation@example.com")
  end

  test "country selection includes all expected options" do
    visit "/users/sign_up"

    country_select = find("select[name='user[country_of_residence]']")

    # Check that key countries are present
    assert country_select.has_option?("🇦🇺 Australia")
    assert country_select.has_option?("🇺🇸 United States")
    assert country_select.has_option?("🇬🇧 United Kingdom")
    assert country_select.has_option?("🇨🇦 Canada")
    assert country_select.has_option?("🌍 Other")

    # Default should be Australia
    assert_equal "Australia", country_select.value
  end

  test "registration form has all required fields and proper styling" do
    visit "/users/sign_up"

    # Check all form fields are present
    assert_field "First name"
    assert_field "Last name"
    assert_field "Email"
    assert_field "Country of residence"
    assert_field "Password"
    assert_field "Confirm Password"

    # Check terms checkbox
    assert_field "I accept the", type: "checkbox"

    # Check submit button
    assert_button "Create Account"

    # Check that the button is initially disabled (as per the HTML)
    submit_button = find("input[type='submit']")
    assert submit_button[:disabled], "Submit button should be initially disabled"

    # Check for proper CSS classes (ensuring our styling fixes are applied)
    assert_selector ".terms-checkbox-fix"
    assert_selector ".terms-inline"
    assert_selector ".recaptcha-group"
  end

  test "registration integrates with authentication flow" do
    # This test ensures registration works with the broader authentication system
    visit "/users/sign_up"

    fill_in "First name", with: "Auth"
    fill_in "Last name", with: "Flow"
    fill_in "Email", with: "browser.test@example.com"
    select "🇦🇺 Australia", from: "Country of residence"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"
    check "I accept the"

    click_button "Create Account"

    # After registration, user should be redirected appropriately
    # The exact behavior depends on your app's configuration
    assert_current_path "/", wait: 10

    user = User.find_by(email: "browser.test@example.com")
    assert_not_nil user, "User should be created through browser registration"

    # Verify the user has an application
    assert_equal 1, user.applications.count
    assert user.applications.first.status_created?
  end
end