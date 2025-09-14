require "test_helper"

class CheckboxLayoutTest < ActionDispatch::IntegrationTest
  test "mortgage checkbox has text first, checkbox second layout" do
    user = users(:jane)
    sign_in user

    get "/applications/new"
    assert_response :success

    # Check that the checkbox group has the reverse class
    assert_match(/checkbox-group-reverse/, response.body, "Should have reverse checkbox layout class")

    # Check that the label wraps the text and checkbox in correct order
    assert_match(/This property has an existing mortgage.*<input.*type="checkbox"/m, response.body, "Text should come before checkbox in HTML structure")

    # Verify the checkbox structure
    assert_match(/data-application-form-target="mortgageCheckbox"/, response.body, "Should have mortgage checkbox target")
    assert_match(/change-&gt;application-form#toggleMortgageAmount/, response.body, "Should have toggle action (HTML escaped)")
  end
end