require "test_helper"

class ApplicationPageCspTest < ActionDispatch::IntegrationTest
  test "application new page has no CSP violations" do
    # Create a user and sign them in
    user = users(:jane)
    sign_in user

    get "/applications/new?home_value=1600000"
    assert_response :success

    # Count inline styles that are NOT from external sources (like reCAPTCHA)
    inline_styles = response.body.scan(/style="[^"]*"/)

    # Filter out any external widget styles (like reCAPTCHA)
    app_inline_styles = inline_styles.reject { |style|
      # Allow external widget styles but not our application styles
      style.include?("width:") && style.include?("height:") && style.include?("position:")
    }

    assert_equal 0, app_inline_styles.count, "Found #{app_inline_styles.count} inline style violations: #{app_inline_styles.inspect}"
  end

  test "application form uses proper CSS classes instead of inline styles" do
    user = users(:jane)
    sign_in user

    get "/applications/new"
    assert_response :success

    # Check that conditional form fields use js-hidden class instead of inline styles
    assert_match(/js-hidden/, response.body, "Should use js-hidden class for conditional visibility")

    # Check that site-* button classes are used
    assert_match(/site-btn site-btn-primary/, response.body, "Should use site-btn classes")
    assert_match(/site-btn site-btn-secondary/, response.body, "Should use site-btn-secondary class")

    # Verify no old CSS framework classes
    assert_no_match(/class="[^"]*\bbtn btn-primary\b/, response.body, "Should not use old btn btn-primary classes")
    assert_no_match(/class="[^"]*\bbtn btn-secondary\b/, response.body, "Should not use old btn btn-secondary classes")
  end

  test "step indicator has proper visibility and styling" do
    user = users(:jane)
    sign_in user

    get "/applications/new"
    assert_response :success

    # Check step indicator structure
    assert_match(/step-indicator/, response.body, "Should have step indicator")
    assert_match(/step-progress/, response.body, "Should have step progress")
    assert_match(/step-item/, response.body, "Should have step items")
    assert_match(/step-number/, response.body, "Should have step numbers")
    assert_match(/step-label/, response.body, "Should have step labels")

    # Check for step states
    assert_match(/step-item completed/, response.body, "Should have completed step")
    assert_match(/step-item active/, response.body, "Should have active step")
  end
end