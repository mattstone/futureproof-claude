require 'test_helper'

class SignupTermsLayoutTest < ActionDispatch::IntegrationTest
  test "terms and conditions checkbox displays properly on signup page" do
    get "/users/sign_up"
    assert_response :success

    # Check that the checkbox-text span is present
    assert_select "span.checkbox-text", text: /I accept the/

    # Check that the terms link is within the checkbox-text span
    assert_select "span.checkbox-text button.terms-link", text: "Terms and Conditions"

    # Check that the checkbox is present in the label
    assert_select "label.checkbox-label input[type=checkbox]"

    # Verify the HTML structure is correct (text followed by checkbox)
    checkbox_group = css_select("div.checkbox-group").first
    assert_not_nil checkbox_group, "Should have checkbox-group div"

    # Verify the label contains both the span and checkbox
    label = checkbox_group.css("label.checkbox-label").first
    assert_not_nil label, "Should have checkbox-label"

    # Check the order: span first, then checkbox
    span = label.css("span.checkbox-text").first
    checkbox = label.css("input[type=checkbox]").first

    assert_not_nil span, "Should have checkbox-text span"
    assert_not_nil checkbox, "Should have checkbox input"

    # The span should come before the checkbox in the DOM
    span_position = label.children.index(span)
    checkbox_position = label.children.index(checkbox)
    assert span_position < checkbox_position, "Text span should come before checkbox in DOM order"

    # Check that the new CSS classes are present for proper styling
    assert_select "div.terms-checkbox-fix", 1, "Should have terms-checkbox-fix class for styling"
    assert_select "label.terms-inline", 1, "Should have terms-inline class for proper layout"
  end
end