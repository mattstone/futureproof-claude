require "application_system_test_case"

class OwnershipFieldDisplaySystemTest < ApplicationSystemTestCase
  def setup
    @user = User.create!(
      email: 'ownership_test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Ownership',
      last_name: 'Test',
      country_of_residence: 'Australia',
      terms_accepted: true
    )
  end

  test "individual ownership shows only borrower name and age fields" do
    sign_in @user
    visit new_application_path

    # Select individual ownership
    select "Individual", from: "application[ownership_status]"

    # Individual fields should be visible
    assert_selector "div[data-application-form-target='individualFields']:not(.js-hidden)", visible: true
    assert_field "application[borrower_names]", visible: true
    assert_field "application[borrower_age]", visible: true

    # Joint fields should be hidden
    assert_selector "div[data-application-form-target='jointFields'].js-hidden", visible: false
    assert_no_field "borrower_name_1", visible: true
    assert_no_field "borrower_name_2", visible: true

    # Super fields should be hidden
    assert_selector "div[data-application-form-target='superFields'].js-hidden", visible: false
    assert_no_field "application[super_fund_name]", visible: true
  end

  test "joint ownership shows only multiple borrower name and age fields" do
    sign_in @user
    visit new_application_path

    # Select joint ownership
    select "Joint Ownership", from: "application[ownership_status]"

    # Joint fields should be visible
    assert_selector "div[data-application-form-target='jointFields']:not(.js-hidden)", visible: true
    assert_field "borrower_name_1", visible: true
    assert_field "borrower_name_2", visible: true
    assert_field "borrower_age_1", visible: true
    assert_field "borrower_age_2", visible: true
    assert_button "Add Another Borrower", visible: true

    # Individual fields should be hidden
    assert_selector "div[data-application-form-target='individualFields'].js-hidden", visible: false
    assert_no_field "application[borrower_names]", visible: true
    assert_no_field "application[borrower_age]", visible: true

    # Super fields should be hidden
    assert_selector "div[data-application-form-target='superFields'].js-hidden", visible: false
    assert_no_field "application[super_fund_name]", visible: true
  end

  test "superannuation ownership shows only fund name field" do
    sign_in @user
    visit new_application_path

    # Select superannuation ownership
    select "Superannuation Fund", from: "application[ownership_status]"

    # Super fields should be visible
    assert_selector "div[data-application-form-target='superFields']:not(.js-hidden)", visible: true
    assert_field "application[super_fund_name]", visible: true

    # Individual fields should be hidden
    assert_selector "div[data-application-form-target='individualFields'].js-hidden", visible: false
    assert_no_field "application[borrower_names]", visible: true
    assert_no_field "application[borrower_age]", visible: true

    # Joint fields should be hidden
    assert_selector "div[data-application-form-target='jointFields'].js-hidden", visible: false
    assert_no_field "borrower_name_1", visible: true
    assert_no_field "borrower_name_2", visible: true
  end

  test "switching between ownership types shows correct fields" do
    sign_in @user
    visit new_application_path

    # Start with individual
    select "Individual", from: "application[ownership_status]"
    assert_field "application[borrower_names]", visible: true
    assert_no_field "borrower_name_1", visible: true
    assert_no_field "application[super_fund_name]", visible: true

    # Switch to joint
    select "Joint Ownership", from: "application[ownership_status]"
    assert_no_field "application[borrower_names]", visible: true
    assert_field "borrower_name_1", visible: true
    assert_field "borrower_name_2", visible: true
    assert_no_field "application[super_fund_name]", visible: true

    # Switch to superannuation
    select "Superannuation Fund", from: "application[ownership_status]"
    assert_no_field "application[borrower_names]", visible: true
    assert_no_field "borrower_name_1", visible: true
    assert_field "application[super_fund_name]", visible: true

    # Switch back to individual
    select "Individual", from: "application[ownership_status]"
    assert_field "application[borrower_names]", visible: true
    assert_no_field "borrower_name_1", visible: true
    assert_no_field "application[super_fund_name]", visible: true
  end

  test "add another borrower works in joint ownership" do
    sign_in @user
    visit new_application_path

    # Select joint ownership
    select "Joint Ownership", from: "application[ownership_status]"

    # Should have 2 borrowers initially
    assert_field "borrower_name_1"
    assert_field "borrower_name_2"

    # Click add another borrower
    click_button "Add Another Borrower"

    # Should now have 3 borrowers
    assert_field "borrower_name_1"
    assert_field "borrower_name_2"
    assert_field "borrower_name_3"
  end

  private

  def sign_in(user)
    visit '/users/sign_in'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign In'
  end
end