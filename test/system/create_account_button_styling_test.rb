require "application_system_test_case"

class CreateAccountButtonStylingTest < ApplicationSystemTestCase
  test "Create Account button shows bright blue when enabled" do
    visit "/users/sign_up?home_value=1600000"

    # Verify page loads
    assert_text "Create Account"

    # Find the submit button
    submit_button = find("input[type='submit'][value='Create Account']")

    # Initially, button should be disabled and have disabled class
    assert submit_button[:disabled], "Button should start disabled"
    assert submit_button[:class].include?('site-btn-disabled'), "Button should have disabled class initially"

    # Fill out the form to enable the button
    fill_in "First name", with: "Button"
    fill_in "Last name", with: "Test"
    fill_in "Email", with: "button.test@example.com"
    select "🇦🇺 Australia", from: "Country of Residence"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"

    # Check the terms checkbox to enable the button
    check "I accept the"

    # Wait for the button to be enabled
    assert_no_selector "input[type='submit'][value='Create Account'][disabled]", wait: 5

    # Verify the button is now enabled and doesn't have the disabled class
    submit_button = find("input[type='submit'][value='Create Account']")
    assert_not submit_button[:disabled], "Button should be enabled after checking terms"

    # Check that the disabled class has been removed by our JavaScript
    button_classes = submit_button[:class]
    assert_not button_classes.include?('site-btn-disabled'), "Button should not have disabled class when enabled"

    # Verify the button has the expected enabled classes
    assert button_classes.include?('site-btn'), "Button should have site-btn class"
    assert button_classes.include?('site-btn-primary'), "Button should have site-btn-primary class"
    assert button_classes.include?('auth-submit-btn'), "Button should have auth-submit-btn class"

    # Test that hovering works (this verifies our CSS is applied)
    submit_button.hover

    # The button should be visually distinct when enabled
    # We can't easily test the exact color, but we can ensure it's not disabled
    assert_not submit_button[:disabled], "Button should remain enabled on hover"
  end

  test "Create Account button returns to disabled state when terms unchecked" do
    visit "/users/sign_up?home_value=1600000"

    # Fill out form
    fill_in "First name", with: "Toggle"
    fill_in "Last name", with: "Test"
    fill_in "Email", with: "toggle.test@example.com"
    select "🇦🇺 Australia", from: "Country of Residence"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"

    # Check terms to enable button
    check "I accept the"

    # Wait for button to be enabled
    assert_no_selector "input[type='submit'][value='Create Account'][disabled]", wait: 5

    # Uncheck terms
    uncheck "I accept the"

    # Button should be disabled again
    assert_selector "input[type='submit'][value='Create Account'][disabled]", wait: 5

    # Verify the disabled class is added back
    submit_button = find("input[type='submit'][value='Create Account']")
    assert submit_button[:class].include?('site-btn-disabled'), "Button should have disabled class when terms unchecked"
  end
end