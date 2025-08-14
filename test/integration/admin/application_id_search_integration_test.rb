require 'test_helper'

class Admin::ApplicationIdSearchIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications

  def setup
    @admin = users(:admin_user)
    sign_in @admin
    
    # Use known fixture applications
    @test_application = applications(:mortgage_application)
    @other_application = applications(:submitted_application)
    
    # Ensure we have different IDs for testing
    assert_not_equal @test_application.id, @other_application.id
  end

  test "admin can search for application by ID via web interface" do
    # Visit the admin applications index page
    get admin_applications_path
    assert_response :success
    
    # Verify the search form exists
    assert_select 'form[action="/admin/applications/search"]'
    assert_select 'input[name="search"][placeholder*="ID"]'
    
    # Search for a specific application by ID
    get admin_applications_path, params: { search: @test_application.id.to_s }
    assert_response :success
    
    # Should find only the specific application
    assert_includes response.body, @test_application.address
    assert_not_includes response.body, @other_application.address
    
    # Should show the application ID in the results
    assert_includes response.body, @test_application.id.to_s
  end

  test "admin can search via dynamic POST request (Turbo Stream)" do
    # Simulate the dynamic search via POST
    post search_admin_applications_path, 
         params: { search: @test_application.id.to_s },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_match "turbo-stream", response.headers["Content-Type"]
    
    # Should find the specific application
    assert_includes response.body, @test_application.address
    assert_not_includes response.body, @other_application.address
  end

  test "admin gets no results when searching for non-existent ID" do
    non_existent_id = Application.maximum(:id).to_i + 999999
    
    get admin_applications_path, params: { search: non_existent_id.to_s }
    assert_response :success
    
    # Should not find any applications
    assert_not_includes response.body, @test_application.address
    assert_not_includes response.body, @other_application.address
  end

  test "admin can combine ID search with status filter" do
    # Search for specific application ID with matching status
    get admin_applications_path, 
        params: { 
          search: @test_application.id.to_s, 
          status: @test_application.status 
        }
    
    assert_response :success
    
    # Should find the application since ID and status match
    assert_includes response.body, @test_application.address
    assert_not_includes response.body, @other_application.address
  end

  test "admin gets no results when ID search doesn't match status filter" do
    # Search for application ID but with wrong status
    wrong_status = Application.statuses.keys.find { |s| s != @test_application.status && s != 'accepted' }
    
    get admin_applications_path, 
        params: { 
          search: @test_application.id.to_s, 
          status: wrong_status 
        }
    
    assert_response :success
    
    # Should not find the application due to status mismatch
    assert_not_includes response.body, @test_application.address
    assert_not_includes response.body, @other_application.address
  end

  test "search form preserves application ID in input field" do
    application_id = @test_application.id.to_s
    
    get admin_applications_path, params: { search: application_id }
    assert_response :success
    
    # Should preserve the search term in the input field
    assert_select "input[name='search'][value='#{application_id}']"
  end

  test "placeholder text indicates ID search capability" do
    get admin_applications_path
    assert_response :success
    
    # Should show updated placeholder text
    assert_select 'input[name="search"][placeholder="Search by ID, address, name, or email..."]'
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end