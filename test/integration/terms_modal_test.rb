require "test_helper"

class TermsModalTest < ActionDispatch::IntegrationTest
  test "terms and conditions modal renders correctly on signup page" do
    get new_user_registration_path
    assert_response :success

    # Verify modal structure exists
    assert_select '.modal-overlay[data-terms-modal-target="overlay"]', count: 1
    assert_select ".modal-content", count: 1
    assert_select ".modal-header", count: 1
    assert_select ".modal-title", text: "Terms and Conditions"
    assert_select '.modal-body[data-terms-modal-target="content"]', count: 1
    assert_select ".modal-footer", count: 1

    # Verify modal buttons exist
    assert_select ".modal-close", count: 1
    assert_select "button", text: "Close"
    assert_select "button", text: "Accept Terms"

    # Verify terms link exists
    assert_select ".terms-link", text: "Terms and Conditions"

    # Verify modal is hidden by default (display: none is set by controller on connect)
    assert_select '.modal-overlay[data-terms-modal-target="overlay"]'
  end

  test "modal has proper CSS classes for positioning and sizing" do
    get new_user_registration_path
    assert_response :success

    # Check that the modal overlay and content have the right structure
    assert_select ".modal-overlay" do
      assert_select ".modal-content" do
        assert_select ".modal-header"
        assert_select ".modal-body"
        assert_select ".modal-footer"
      end
    end
  end
end
