require "test_helper"

class OwnershipFieldCorrectDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular_user)
    sign_in @user
  end

  test "individual ownership fields show by default, joint and super fields hidden" do
    get new_application_path
    assert_response :success

    # Individual fields should be visible (default ownership is individual)
    assert_select "div[data-application-form-target='individualFields']:not(.js-hidden)"

    # Joint and superannuation fields should be hidden
    assert_select "div[data-application-form-target='jointFields'].js-hidden"
    assert_select "div[data-application-form-target='superFields'].js-hidden"

    # Individual field elements should exist
    assert_select "input[name='application[borrower_age]']"

    # Joint borrower elements should exist but be in hidden container
    assert_select "#joint-borrowers"

    # Superannuation field should exist but be in hidden container
    assert_select "input[name='application[super_fund_name]']"
  end

  test "ownership select has individual as default option" do
    get new_application_path
    assert_response :success

    # Check that individual is the selected option
    assert_select "select[name='application[ownership_status]'] option[selected]", text: "Individual"
  end
end