require "test_helper"

class Admin::TablesAndLinkingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    sign_in users(:admin_user)
  end

  test "applications sort by home_value ascending" do
    get admin_applications_path(sort: "home_value", direction: "asc")
    assert_response :success
    assert_select "a.sortable-header-active", text: /Property/
  end

  test "sort parameter outside the whitelist is ignored" do
    get admin_applications_path(sort: "users.encrypted_password", direction: "asc")
    assert_response :success
  end

  test "applications CSV export respects filters" do
    get admin_applications_path(format: :csv, status: "submitted")
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "ID,Customer,Email", response.body
    assert_match applications(:submitted_application).address, response.body
    assert_no_match applications(:accepted_application).address, response.body
  end

  test "contracts CSV export works" do
    get admin_contracts_path(format: :csv)
    assert_response :success
    assert_match "ID,Customer,Application", response.body
  end

  test "users CSV export works" do
    get admin_users_path(format: :csv)
    assert_response :success
    assert_match users(:regular_user).email, response.body
  end

  test "application show renders the related records strip" do
    get admin_application_path(applications(:submitted_application))
    assert_select ".related-records .related-record-link"
  end

  test "user show lists related applications" do
    user = applications(:submitted_application).user
    get admin_user_path(user)
    assert_select ".related-record-link", text: /Application ##{applications(:submitted_application).id}/
  end
end
