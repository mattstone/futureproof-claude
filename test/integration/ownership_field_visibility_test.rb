require "test_helper"

class OwnershipFieldVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular_user)
    sign_in @user
  end

  test "ownership fields display correctly based on default ownership type" do
    get new_application_path
    assert_response :success

    # Individual fields should be visible (default ownership is individual)
    assert_select "div[data-application-form-target='individualFields']:not(.js-hidden)"

    # Joint and superannuation fields should be hidden by default
    assert_select "div[data-application-form-target='jointFields'].js-hidden"
    assert_select "div[data-application-form-target='superFields'].js-hidden"

    # Ownership select should exist
    assert_select "select[name='application[ownership_status]']"

    # All field types should exist
    assert_select "input[name='application[borrower_age]']"
    assert_select "input[name='application[super_fund_name]']"
    assert_select "#joint-borrowers"
  end
end