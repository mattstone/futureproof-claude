require "test_helper"

class ApplicationOwnershipFieldsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular_user)
    sign_in @user
    @application = applications(:mortgage_application)
  end

  test "form loads with ownership and mortgage fields" do
    get new_application_path
    assert_response :success

    # Check ownership select exists
    assert_select "select[name='application[ownership_status]']"

    # Check superannuation field exists with target
    assert_select "div[data-application-form-target='superFields']"

    # Check mortgage checkbox exists
    assert_select "input[name='application[has_existing_mortgage]']"

    # Check mortgage fields exist with targets
    assert_select "div[data-application-form-target='mortgageAmountGroup']"
    assert_select "div[data-application-form-target='mortgageLenderGroup']"

    # Check existing mortgage lender field exists
    assert_select "input[name='application[existing_mortgage_lender]']"
  end

  test "auto-save works for ownership status changes" do
    patch application_path(@application), params: {
      application: { ownership_status: "super" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    @application.reload
    assert_equal "super", @application.ownership_status
  end

  test "auto-save works for mortgage checkbox changes" do
    patch application_path(@application), params: {
      application: {
        has_existing_mortgage: "1",
        existing_mortgage_lender: "Test Bank"
      }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    @application.reload
    assert @application.has_existing_mortgage
    assert_equal "Test Bank", @application.existing_mortgage_lender
  end
end