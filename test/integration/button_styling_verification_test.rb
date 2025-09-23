require 'test_helper'

class ButtonStylingVerificationTest < ActionDispatch::IntegrationTest
  test "signup page has correct button and checkbox structure for styling" do
    get "/users/sign_up?home_value=1600000"
    assert_response :success

    # Verify the Create Account button exists with correct classes
    assert_select "input[type='submit'][value='Create Account']" do |elements|
      button = elements.first
      classes = button['class']

      # Verify all expected classes are present
      assert classes.include?('site-btn'), "Button should have site-btn class"
      assert classes.include?('site-btn-primary'), "Button should have site-btn-primary class"
      assert classes.include?('auth-submit-btn'), "Button should have auth-submit-btn class"
      assert classes.include?('site-btn-disabled'), "Button should start with site-btn-disabled class"

      # Verify initial disabled state
      assert button['disabled'], "Button should start disabled"
    end

    # Verify the terms checkbox exists
    assert_select "input[name='user[terms_accepted]'][type='checkbox']", 1, "Should have exactly one terms checkbox"

    # Verify the terms modal controller is present
    assert_select "[data-controller*='terms-modal']", 1, "Should have terms-modal controller"

    # Verify the button is within a form
    assert_select "form input[type='submit'][value='Create Account']", 1, "Button should be in a form"
  end

  test "page loads CSS that includes our button styling rules" do
    get "/users/sign_up"
    assert_response :success

    # Check that the response includes CSS links
    assert_select "link[rel='stylesheet']", { minimum: 1 }, "Page should include CSS files"

    # The actual CSS content testing is complex in integration tests,
    # but we can verify the basic structure is correct
    assert_select ".terms-checkbox-fix", 1, "Should have our terms checkbox fix styling"
    assert_select ".recaptcha-group", 1, "Should have recaptcha styling"
  end

  test "button has correct attributes for JavaScript interaction" do
    get "/users/sign_up"
    assert_response :success

    # Check that the button can be found by our JavaScript selector
    # Our JS looks for: input[type="submit"][value="Create Account"]
    assert_select "input[type='submit'][value='Create Account']", 1

    # Check that the checkbox can be found by our JavaScript selector
    # Our JS looks for: input[name="user[terms_accepted]"][type="checkbox"]
    assert_select "input[name='user[terms_accepted]'][type='checkbox']", 1

    # Verify the terms modal has the right data action
    assert_select "button[data-action*='terms-modal#open']", 1, "Terms link should have correct action"
  end

  test "CSS and JavaScript files are properly linked" do
    get "/users/sign_up"
    assert_response :success

    # Verify CSS is included (auth.css is compiled into application.css)
    assert_select "link[href*='application'][href*='.css']", { minimum: 1 }

    # Verify JavaScript is included
    assert_select "script[src*='application'][src*='.js'], script[type='importmap']", { minimum: 1 }
  end
end