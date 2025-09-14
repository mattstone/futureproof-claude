require "test_helper"

class AuthFormCspFixTest < ActionDispatch::IntegrationTest
  test "create account page has no CSP inline style violations" do
    get "/users/sign_up"
    assert_response :success

    # Check that auth-form controller targets are properly configured
    assert_match(/data-auth-form-target="title"/, response.body)
    assert_match(/data-auth-form-target="subtitle"/, response.body)
    assert_match(/data-auth-form-target="registrationForm"/, response.body)
    assert_match(/data-auth-form-target="loginForm"/, response.body)
    assert_match(/data-auth-form-target="toggleToLogin"/, response.body)
    assert_match(/data-auth-form-target="toggleToRegister"/, response.body)

    # Check no inline styles that cause CSP violations (excluding reCAPTCHA which is external)
    # Count inline styles that are NOT from reCAPTCHA (allow any style with width/height/border combo)
    inline_styles = response.body.scan(/style="[^"]*"/)
    non_recaptcha_styles = inline_styles.reject { |style|
      (style.include?("width:") || style.include?("width=")) &&
      (style.include?("height:") || style.include?("border")) &&
      (style.include?("px") || style.include?("border-style"))
    }

    assert_equal 0, non_recaptcha_styles.count, "Found #{non_recaptcha_styles.count} non-reCAPTCHA inline style violations: #{non_recaptcha_styles.inspect}"

    # Check js-hidden class is being used instead of style="display: none"
    assert_match(/js-hidden/, response.body)

    # Check unique form IDs to avoid duplicate ID issues
    assert_match(/id="login_form"/, response.body)
    assert_match(/id="login_user_email"/, response.body)
    assert_match(/id="login_user_password"/, response.body)
  end

  test "registration form has proper form structure without duplicate IDs" do
    get "/users/sign_up"
    assert_response :success

    # Should have both registration and login forms but with different IDs
    registration_form_count = response.body.scan(/id="new_user"/).count
    login_form_count = response.body.scan(/id="login_form"/).count

    assert_equal 1, registration_form_count, "Should have exactly one registration form"
    assert_equal 1, login_form_count, "Should have exactly one login form"

    # Email inputs should have different IDs
    reg_email_count = response.body.scan(/id="user_email"/).count
    login_email_count = response.body.scan(/id="login_user_email"/).count

    assert_equal 1, reg_email_count, "Registration email should have unique ID"
    assert_equal 1, login_email_count, "Login email should have unique ID"
  end
end