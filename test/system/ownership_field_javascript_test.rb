require "application_system_test_case"

class OwnershipFieldJavascriptTest < ApplicationSystemTestCase
  def setup
    @user = users(:regular_user)
  end

  test "superannuation field shows only when superannuation is selected" do
    sign_in @user
    visit new_application_path

    # Initially all ownership fields should be hidden
    assert_selector "div[data-application-form-target='individualFields'].js-hidden", visible: false
    assert_selector "div[data-application-form-target='jointFields'].js-hidden", visible: false
    assert_selector "div[data-application-form-target='superFields'].js-hidden", visible: false

    # Select individual ownership - individual field should show
    select "Individual", from: "application[ownership_status]"
    assert_selector "div[data-application-form-target='individualFields']:not(.js-hidden)", visible: true
    assert_selector "div[data-application-form-target='superFields'].js-hidden", visible: false

    # Select superannuation ownership - super field should show
    select "Superannuation Fund", from: "application[ownership_status]"
    assert_selector "div[data-application-form-target='superFields']:not(.js-hidden)", visible: true
    assert_selector "div[data-application-form-target='individualFields'].js-hidden", visible: false

    # Verify superannuation fund name field is visible
    assert_field "application[super_fund_name]", visible: true
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_on "Sign in"
  end
end