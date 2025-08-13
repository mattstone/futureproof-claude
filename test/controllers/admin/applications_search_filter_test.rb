require 'test_helper'

class Admin::ApplicationsSearchFilterTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications

  def setup
    @admin = users(:admin_user)
    sign_in @admin

    # Use fixture applications for testing
    @john_main_street = applications(:mortgage_application) # John's application at 123 Main Street
    @john_elm_street = applications(:submitted_application) # John's application at 789 Elm Street  
    @jane_oak_avenue = applications(:second_application) # Jane's application at 456 Oak Avenue

    # Create an accepted application that should NOT appear in results
    @accepted_app = Application.create!(
      user: users(:jane),
      address: '999 Accepted Avenue, Hidden City, HC 99999',
      home_value: 800000,
      status: :accepted, # This should be filtered out
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 60
    )
  end

  test "should have dynamic search input with oninput attribute using POST" do
    get admin_applications_path
    assert_response :success
    
    # Check that the search form uses POST to search action with Turbo Stream
    assert_select 'form[action="/admin/applications/search"][method="post"][data-turbo-stream="true"]'
    assert_select 'input[name="search"][oninput="this.form.requestSubmit();"]'
  end

  test "should have dynamic status filter with onchange attribute using POST" do
    get admin_applications_path
    assert_response :success
    
    # Check that the filter form uses POST to search action with Turbo Stream
    assert_select 'form[action="/admin/applications/search"][method="post"][data-turbo-stream="true"]'
    assert_select 'select[name="status"][onchange="this.form.requestSubmit();"]'
  end

  test "should handle search via POST request with turbo stream" do
    post search_admin_applications_path, params: { search: users(:john).first_name }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    # Should return turbo stream response that updates the results frame
    assert_response :success
    assert_match "turbo-stream", response.headers["Content-Type"]
    assert_includes response.body, '<turbo-stream action="replace" target="applications_results">'
  end

  test "should have turbo frame wrapping results" do
    get admin_applications_path
    assert_response :success
    
    # Check that results are wrapped in turbo frame
    assert_select 'turbo-frame[id="applications_results"]'
    assert_select 'turbo-frame[id="applications_results"] .admin-table'
  end

  test "should have action links that break out of turbo frame" do
    get admin_applications_path
    assert_response :success
    
    # Check that action links have data-turbo-frame="_top" to break out of frame
    assert_select 'turbo-frame[id="applications_results"] a[data-turbo-frame="_top"]'
  end

  test "should search applications by customer first name" do
    get admin_applications_path, params: { search: users(:john).first_name }
    assert_response :success
    
    # Should find applications by John but not accepted ones
    assert_match @john_main_street.address, response.body
    assert_match @john_elm_street.address, response.body
    
    # Should not find Jane's applications
    assert_no_match @jane_oak_avenue.address, response.body
    
    # Should not find accepted application even if it matches search
    assert_no_match @accepted_app.address, response.body
  end

  test "should search applications by customer last name" do
    get admin_applications_path, params: { search: users(:jane).last_name }
    assert_response :success
    
    # Should find Jane's non-accepted application
    assert_match @jane_oak_avenue.address, response.body
    
    # Should not find John's applications
    assert_no_match @john_main_street.address, response.body
    assert_no_match @john_elm_street.address, response.body
    
    # Should not find accepted application
    assert_no_match @accepted_app.address, response.body
  end

  test "should search applications by customer email" do
    get admin_applications_path, params: { search: users(:john).email }
    assert_response :success
    
    # Should find John's applications but not accepted ones
    assert_match @john_main_street.address, response.body
    assert_match @john_elm_street.address, response.body
    
    # Should not find Jane's applications
    assert_no_match @jane_oak_avenue.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "should search applications by property address" do
    get admin_applications_path, params: { search: 'Main Street' }
    assert_response :success
    
    # Should find the matching address
    assert_match @john_main_street.address, response.body
    
    # Should not find other addresses
    assert_no_match @jane_oak_avenue.address, response.body
    assert_no_match @john_elm_street.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "should search applications case insensitively" do
    get admin_applications_path, params: { search: 'MAIN STREET' }
    assert_response :success
    
    # Should find the matching address regardless of case
    assert_match @john_main_street.address, response.body
  end

  test "should filter applications by status submitted" do
    get admin_applications_path, params: { status: 'submitted' }
    assert_response :success
    
    # Should find submitted application
    assert_match @john_elm_street.address, response.body
    
    # Should not find other status applications
    assert_no_match @john_main_street.address, response.body
    assert_no_match @jane_oak_avenue.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "should filter applications by status property_details" do
    get admin_applications_path, params: { status: 'property_details' }
    assert_response :success
    
    # Should find property_details applications
    assert_match @john_main_street.address, response.body
    assert_match @jane_oak_avenue.address, response.body
    
    # Should not find other status applications
    assert_no_match @john_elm_street.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "should filter applications by status created" do
    get admin_applications_path, params: { status: 'created' }
    assert_response :success
    
    # Should not find any applications with created status in fixtures
    assert_no_match @john_main_street.address, response.body
    assert_no_match @jane_oak_avenue.address, response.body
    assert_no_match @john_elm_street.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "should never show accepted applications in any filter" do
    get admin_applications_path, params: { status: 'accepted' }
    assert_response :success
    
    # Should not find accepted application even when specifically filtered
    assert_no_match @accepted_app.address, response.body
    
    # Should show empty results message or other applications
    # but definitely not the accepted one
  end

  test "should combine search and status filter" do
    get admin_applications_path, params: { search: users(:john).first_name, status: 'submitted' }
    assert_response :success
    
    # Should find John's submitted application
    assert_match @john_elm_street.address, response.body
    
    # Should not find John's property_details application (wrong status)
    assert_no_match @john_main_street.address, response.body
    
    # Should not find Jane's application (wrong user)
    assert_no_match @jane_oak_avenue.address, response.body
    
    # Should not find accepted application
    assert_no_match @accepted_app.address, response.body
  end

  test "should preserve search when filtering by status" do
    get admin_applications_path, params: { search: users(:john).first_name, status: 'submitted' }
    assert_response :success
    
    # Check that both search and status parameters are preserved in forms
    assert_select 'input[name="search"][value=?]', users(:john).first_name
    assert_select 'select[name="status"] option[selected="selected"][value="submitted"]'
  end

  test "should preserve status when searching" do
    get admin_applications_path, params: { search: 'Main', status: 'property_details' }
    assert_response :success
    
    # Check that both search and status parameters are preserved in forms
    assert_select 'input[name="search"][value="Main"]'
    assert_select 'select[name="status"] option[selected="selected"][value="property_details"]'
  end

  test "should show status options excluding accepted" do
    get admin_applications_path
    assert_response :success
    
    # Should have all status options except accepted
    assert_select 'select[name="status"] option[value="created"]'
    assert_select 'select[name="status"] option[value="property_details"]'
    assert_select 'select[name="status"] option[value="income_and_loan_options"]'
    assert_select 'select[name="status"] option[value="submitted"]'
    assert_select 'select[name="status"] option[value="processing"]'
    assert_select 'select[name="status"] option[value="rejected"]'
    
    # Should NOT have accepted option
    assert_select 'select[name="status"] option[value="accepted"]', count: 0
  end

  test "should handle empty search results" do
    get admin_applications_path, params: { search: 'NonexistentSearchTerm12345' }
    assert_response :success
    
    # Should not show any applications
    assert_no_match @john_main_street.address, response.body
    assert_no_match @jane_oak_avenue.address, response.body
    assert_no_match @john_elm_street.address, response.body
  end

  test "should handle empty filter results" do
    get admin_applications_path, params: { status: 'rejected' }
    assert_response :success
    
    # Should show empty state message or no results
    # (depends on if there are rejected applications in fixtures)
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end