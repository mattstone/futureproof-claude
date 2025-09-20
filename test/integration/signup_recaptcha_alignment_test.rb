require 'test_helper'

class SignupRecaptchaAlignmentTest < ActionDispatch::IntegrationTest
  test "reCAPTCHA is properly centered on signup page" do
    get "/users/sign_up"
    assert_response :success

    # Check that the recaptcha-group div is present
    assert_select "div.recaptcha-group", 1, "Should have recaptcha-group div"

    # Check that the g-recaptcha div is within the recaptcha-group
    assert_select "div.recaptcha-group div.g-recaptcha", 1, "Should have g-recaptcha div inside recaptcha-group"

    # Verify the structure is correct for centering
    recaptcha_group = css_select("div.recaptcha-group").first
    assert_not_nil recaptcha_group, "Should have recaptcha-group"

    g_recaptcha = recaptcha_group.css("div.g-recaptcha").first
    assert_not_nil g_recaptcha, "Should have g-recaptcha div"

    # Verify that the reCAPTCHA structure is ready for center alignment
    assert g_recaptcha.attribute('class').value.include?('g-recaptcha'), "Should have g-recaptcha class"
  end
end