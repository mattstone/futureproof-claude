require 'test_helper'

class Admin::ApplicationsFilteringTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts

  def setup
    @admin = users(:admin_user)
    sign_in @admin
    
    # Create applications with different statuses for testing
    @created_app = applications(:mortgage_application)
    @created_app.update!(status: :created)
    
    @submitted_app = applications(:second_application)
    @submitted_app.update!(status: :submitted)
    
    @processing_app = applications(:submitted_application)
    @processing_app.update!(status: :processing)
    
    # Create an accepted application
    @accepted_app = Application.create!(
      user: users(:jane),
      address: '999 Accepted Street, Accepted City',
      home_value: 800000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 40
    )
  end

  test "index should exclude accepted applications by default" do
    get admin_applications_path
    assert_response :success
    
    # Should show non-accepted applications
    assert_match @created_app.address, response.body
    assert_match @submitted_app.address, response.body
    assert_match @processing_app.address, response.body
    
    # Should not show accepted application
    assert_no_match @accepted_app.address, response.body
  end

  test "search includes accepted applications (admins must always be able to find a record)" do
    get admin_applications_path, params: { search: 'Accepted' }
    assert_response :success

    assert_match @accepted_app.address, response.body
  end

  test "search should still find non-accepted applications" do
    # Search for a term that matches non-accepted applications
    get admin_applications_path, params: { search: 'Main' }
    assert_response :success
    
    # Should show the mortgage_application which has "Main Street" in address
    assert_match @created_app.address, response.body
  end

  test "status filter includes the accepted option" do
    get admin_applications_path
    assert_response :success

    assert_match 'option value="accepted"', response.body
    assert_match 'option value="created"', response.body
    assert_match 'option value="submitted"', response.body
    assert_match 'option value="processing"', response.body
    assert_match 'option value="rejected"', response.body
  end

  test "explicit accepted status filter shows accepted applications" do
    get admin_applications_path, params: { status: 'accepted' }
    assert_response :success

    assert_match @accepted_app.address, response.body
    assert_no_match @created_app.address, response.body
  end

  test "status filter with valid non-accepted status should work" do
    get admin_applications_path, params: { status: 'submitted' }
    assert_response :success
    
    # Should show only submitted applications
    assert_match @submitted_app.address, response.body
    
    # Should not show other statuses
    assert_no_match @created_app.address, response.body
    assert_no_match @processing_app.address, response.body
    assert_no_match @accepted_app.address, response.body
  end

  test "combined search and status filter should exclude accepted applications" do
    # Update an application to have searchable text and submitted status
    @submitted_app.update!(address: '123 Searchable Street, Test City')
    
    get admin_applications_path, params: { 
      search: 'Searchable', 
      status: 'submitted' 
    }
    assert_response :success
    
    # Should find the submitted application with matching search term
    assert_match 'Searchable Street', response.body
    
    # Should not show accepted application even if it had matching text
    assert_no_match @accepted_app.address, response.body
  end

  test "user search results include accepted applications" do
    # Search by the user's name who has an accepted application
    jane = users(:jane)
    get admin_applications_path, params: { search: jane.first_name }
    assert_response :success

    assert_match @accepted_app.address, response.body
  end

  test "accepted applications can still be accessed directly via show page" do
    get admin_application_path(@accepted_app)
    assert_response :success
    
    # Should be able to view the accepted application details
    assert_match @accepted_app.address, response.body
    assert_match 'Accepted', response.body
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password1234' }
    }
  end
end