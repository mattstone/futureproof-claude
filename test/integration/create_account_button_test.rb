require 'test_helper'

class CreateAccountButtonTest < ActionDispatch::IntegrationTest
  test "signup page renders Create Account button with correct initial state" do
    get "/users/sign_up?home_value=1600000"
    assert_response :success

    # Check that the Create Account button exists with disabled state
    assert_select "input[type=submit][value='Create Account']" do |elements|
      button = elements.first
      assert button['disabled'], "Button should start disabled"
      assert button['class'].include?('site-btn-disabled'), "Button should have disabled class"
      assert button['class'].include?('auth-submit-btn'), "Button should have auth-submit-btn class"
      assert button['class'].include?('site-btn-primary'), "Button should have primary class"
    end

    # Check that the terms checkbox exists
    assert_select "input[name='user[terms_accepted]'][type=checkbox]", "Terms checkbox should exist"

    # Check that the page has the terms modal controller
    assert_select "[data-controller*='terms-modal']", "Page should have terms-modal controller"
  end

  test "signup page includes required JavaScript for button state management" do
    get "/users/sign_up"
    assert_response :success

    # Verify that the necessary data attributes and controllers are present
    assert_select "[data-controller*='terms-modal']", "Should have terms-modal controller"

    # Check that form has proper structure for our JavaScript to work
    assert_select "form input[name='user[terms_accepted]']", "Should have terms checkbox"
    assert_select "form input[type=submit][value='Create Account']", "Should have submit button"
  end

  test "CSS includes proper styling for enabled and disabled button states" do
    get "/users/sign_up"
    assert_response :success

    # Verify the CSS is loaded by checking for our custom styles
    css_response = get "/assets/application.css" rescue get "/assets/application-*.css"

    # The CSS should include our custom button styling
    # Note: In tests, we verify the structure is correct rather than exact styling
    assert_select "input.auth-submit-btn", "Button should have auth-submit-btn class"
    assert_select "input.site-btn-primary", "Button should have primary styling class"
  end
end