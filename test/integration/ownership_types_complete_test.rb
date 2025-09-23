require "test_helper"

class OwnershipTypesCompleteTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular_user)
    sign_in @user
  end

  test "individual ownership shows borrower name and age only" do
    get new_application_path
    assert_response :success

    # Individual fields should be visible (default)
    assert_select "div[data-application-form-target='individualFields']:not(.js-hidden)"

    # Individual fields should contain name and age
    assert_select "input[name='application[borrower_names]']"
    assert_select "input[name='application[borrower_age]']"

    # Joint and super fields should be hidden
    assert_select "div[data-application-form-target='jointFields'].js-hidden"
    assert_select "div[data-application-form-target='superFields'].js-hidden"
  end

  test "joint ownership shows borrower names and ages with add button" do
    get new_application_path
    assert_response :success

    # Joint fields should exist but be hidden
    assert_select "div[data-application-form-target='jointFields'].js-hidden"

    # Joint fields should contain first and second borrower names and ages
    assert_select "input[name='borrower_name_1']"
    assert_select "input[name='borrower_name_2']"
    assert_select "input[name='borrower_age_1']"
    assert_select "input[name='borrower_age_2']"

    # Add another borrower button should exist
    assert_select "button#add-borrower"
  end

  test "superannuation ownership shows only fund name" do
    get new_application_path
    assert_response :success

    # Super fields should exist but be hidden
    assert_select "div[data-application-form-target='superFields'].js-hidden"

    # Super fields should only contain fund name
    assert_select "input[name='application[super_fund_name]']"

    # Super section should not contain any sliders for age
    assert_select "div[data-application-form-target='superFields'] input[type='range']", count: 0
  end

  test "ownership select has correct options" do
    get new_application_path
    assert_response :success

    # Check ownership select options
    assert_select "select[name='application[ownership_status]'] option[value='individual']", text: "Individual"
    assert_select "select[name='application[ownership_status]'] option[value='joint']", text: "Joint Ownership"
    assert_select "select[name='application[ownership_status]'] option[value='super']", text: "Superannuation Fund"
  end
end