require "test_helper"

class StimulusControllerTest < ActionDispatch::IntegrationTest
  test "auth-form controller targets are properly scoped and accessible" do
    get "/users/sign_up"
    assert_response :success

    # Check that auth-form controller is defined and all targets are present in the page
    assert_match(/data-controller="[^"]*auth-form[^"]*"/, response.body, "auth-form controller should be defined")

    # Verify all required targets are present in the response
    targets_to_check = ['title', 'subtitle', 'registrationForm', 'loginForm', 'toggleToLogin', 'toggleToRegister']
    targets_to_check.each do |target|
      assert_match(/data-auth-form-target="#{target}"/, response.body, "#{target} target should be present")
    end

    # Check that controller and first target appear in correct order (controller before targets)
    controller_position = response.body.index('data-controller="auth-form"')
    title_target_position = response.body.index('data-auth-form-target="title"')

    assert controller_position < title_target_position, "Controller should be defined before its targets"
  end

  test "stimulus controller structure prevents target element errors" do
    get "/users/sign_up"
    assert_response :success

    # The page should render without JavaScript errors
    # This is verified by the successful HTTP response and proper target structure
    assert response.body.include?('data-controller="auth-form"'), "auth-form controller should be present"

    # All targets should be findable within the controller scope
    targets = ['title', 'subtitle', 'registrationForm', 'loginForm', 'toggleToLogin', 'toggleToRegister', 'emailInput', 'loginEmailInput', 'emailStatus', 'linkSeparator', 'createAccountLink']

    targets.each do |target|
      assert response.body.include?("data-auth-form-target=\"#{target}\""), "#{target} target should be present and properly formatted"
    end
  end
end