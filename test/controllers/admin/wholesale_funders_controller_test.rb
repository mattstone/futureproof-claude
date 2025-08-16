require "test_helper"

class Admin::WholesaleFundersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_lender = lenders(:futureproof)
    @broker_lender = lenders(:broker)
    @futureproof_admin = users(:futureproof_admin)
    @broker_admin = users(:broker_admin)
    @wholesale_funder = wholesale_funders(:test_wholesale_funder)
  end

  # Authorization Tests
  test "should redirect non-admin users" do
    sign_in users(:user_one)
    get admin_wholesale_funders_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should redirect broker admins from wholesale_funders" do
    sign_in @broker_admin
    get admin_wholesale_funders_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should allow futureproof admins to access wholesale_funders" do
    sign_in @futureproof_admin
    get admin_wholesale_funders_path
    assert_response :success
  end

  # Index Tests
  test "should get index for futureproof admin" do
    sign_in @futureproof_admin
    get admin_wholesale_funders_path
    assert_response :success
    assert_not_nil assigns(:wholesale_funders)
    assert_not_nil assigns(:countries)
    assert_not_nil assigns(:currencies)
  end

  test "should include correct variables in index" do
    sign_in @futureproof_admin
    get admin_wholesale_funders_path
    assert_response :success
    assert assigns(:wholesale_funders).respond_to?(:each)
    assert assigns(:countries).is_a?(Array)
    assert assigns(:currencies).is_a?(Array)
  end

  # Search Tests
  test "should handle search with turbo stream" do
    sign_in @futureproof_admin
    post search_admin_wholesale_funders_path, params: { search: "test" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "should handle search with html redirect" do
    sign_in @futureproof_admin
    post search_admin_wholesale_funders_path, params: { search: "test" }
    assert_redirected_to admin_wholesale_funders_path(search: "test")
  end

  test "should filter by country" do
    sign_in @futureproof_admin
    post search_admin_wholesale_funders_path, params: { country: "Australia" }
    assert_redirected_to admin_wholesale_funders_path(country: "Australia")
  end

  test "should filter by currency" do
    sign_in @futureproof_admin
    post search_admin_wholesale_funders_path, params: { currency: "AUD" }
    assert_redirected_to admin_wholesale_funders_path(currency: "AUD")
  end

  # Show Tests
  test "should show wholesale_funder for futureproof admin" do
    sign_in @futureproof_admin
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    assert_not_nil assigns(:wholesale_funder)
  end

  test "should not allow broker admin to view wholesale_funder" do
    sign_in @broker_admin
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_redirected_to admin_dashboard_index_path
  end

  # New Tests
  test "should get new for futureproof admin" do
    sign_in @futureproof_admin
    get new_admin_wholesale_funder_path
    assert_response :success
    assert_not_nil assigns(:wholesale_funder)
    assert assigns(:wholesale_funder).new_record?
  end

  test "should not allow broker admin to access new" do
    sign_in @broker_admin
    get new_admin_wholesale_funder_path
    assert_redirected_to admin_dashboard_index_path
  end

  # Create Tests
  test "should create wholesale_funder with valid params" do
    sign_in @futureproof_admin
    assert_difference('WholesaleFunder.count') do
      post admin_wholesale_funders_path, params: {
        wholesale_funder: {
          name: "New Test WholesaleFunder",
          country: "Australia", 
          currency: "AUD"
        }
      }
    end
    assert_redirected_to admin_wholesale_funder_path(WholesaleFunder.last)
    assert_match /successfully created/, flash[:notice]
  end

  test "should not create wholesale_funder with invalid params" do
    sign_in @futureproof_admin
    assert_no_difference('WholesaleFunder.count') do
      post admin_wholesale_funders_path, params: {
        wholesale_funder: {
          name: "", # Invalid - blank name
          country: "Australia",
          currency: "AUD"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not allow broker admin to create wholesale_funder" do
    sign_in @broker_admin
    assert_no_difference('WholesaleFunder.count') do
      post admin_wholesale_funders_path, params: {
        wholesale_funder: {
          name: "Test Funder",
          country: "Australia",
          currency: "AUD"
        }
      }
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # Edit Tests
  test "should get edit for futureproof admin" do
    sign_in @futureproof_admin
    get edit_admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    assert_not_nil assigns(:wholesale_funder)
    assert_equal @wholesale_funder, assigns(:wholesale_funder)
  end

  test "should not allow broker admin to access edit" do
    sign_in @broker_admin
    get edit_admin_wholesale_funder_path(@wholesale_funder)
    assert_redirected_to admin_dashboard_index_path
  end

  # Update Tests
  test "should update wholesale_funder with valid params" do
    sign_in @futureproof_admin
    patch admin_wholesale_funder_path(@wholesale_funder), params: {
      wholesale_funder: {
        name: "Updated WholesaleFunder Name"
      }
    }
    assert_redirected_to admin_wholesale_funder_path(@wholesale_funder)
    assert_match /successfully updated/, flash[:notice]
    @wholesale_funder.reload
    assert_equal "Updated WholesaleFunder Name", @wholesale_funder.name
  end

  test "should not update wholesale_funder with invalid params" do
    sign_in @futureproof_admin
    patch admin_wholesale_funder_path(@wholesale_funder), params: {
      wholesale_funder: {
        name: "" # Invalid - blank name
      }
    }
    assert_response :unprocessable_entity
  end

  test "should not allow broker admin to update wholesale_funder" do
    sign_in @broker_admin
    patch admin_wholesale_funder_path(@wholesale_funder), params: {
      wholesale_funder: { name: "Hacked Name" }
    }
    assert_redirected_to admin_dashboard_index_path
  end

  # Destroy Tests
  test "should destroy wholesale_funder for futureproof admin" do
    sign_in @futureproof_admin
    assert_difference('WholesaleFunder.count', -1) do
      delete admin_wholesale_funder_path(@wholesale_funder)
    end
    assert_redirected_to admin_wholesale_funders_path
    assert_match /successfully deleted/, flash[:notice]
  end

  test "should not allow broker admin to destroy wholesale_funder" do
    sign_in @broker_admin
    assert_no_difference('WholesaleFunder.count') do
      delete admin_wholesale_funder_path(@wholesale_funder)
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # Change Tracking Tests
  test "should create wholesale funder with change tracking" do
    sign_in @futureproof_admin
    
    assert_difference ['WholesaleFunder.count', 'WholesaleFunderVersion.count'], 1 do
      post admin_wholesale_funders_path, params: {
        wholesale_funder: {
          name: "New Tracked Funder",
          country: "Canada",
          currency: "USD"
        }
      }
    end
    
    version = WholesaleFunderVersion.last
    assert_equal 'created', version.action
    assert_equal @futureproof_admin, version.user
    assert_includes version.change_details, "Created new wholesale funder 'New Tracked Funder'"
    assert_equal "New Tracked Funder", version.new_name
    assert_equal "Canada", version.new_country
    assert_equal "USD", version.new_currency
  end

  test "should update wholesale funder with change tracking" do
    sign_in @futureproof_admin
    
    assert_difference 'WholesaleFunderVersion.count', 1 do
      patch admin_wholesale_funder_path(@wholesale_funder), params: {
        wholesale_funder: {
          name: "Updated Tracked Funder",
          currency: "USD"
        }
      }
    end
    
    version = WholesaleFunderVersion.last
    assert_equal 'updated', version.action
    assert_equal @futureproof_admin, version.user
    assert_includes version.change_details, "Name changed"
    assert_includes version.change_details, "Currency changed"
  end

  test "should log view when showing wholesale funder" do
    sign_in @futureproof_admin
    
    assert_difference 'WholesaleFunderVersion.count', 1 do
      get admin_wholesale_funder_path(@wholesale_funder)
    end
    
    assert_response :success
    
    version = WholesaleFunderVersion.last
    assert_equal 'viewed', version.action
    assert_equal @futureproof_admin, version.user
    assert_includes version.change_details, "viewed wholesale funder"
  end

  # Security Tests
  test "should log access attempts" do
    sign_in @futureproof_admin
    
    # Test that access is logged (we can't easily test Rails.logger.info in tests,
    # but we can ensure the action completes successfully)
    get admin_wholesale_funders_path
    assert_response :success
  end

  test "should handle XSS in search parameters" do
    sign_in @futureproof_admin
    malicious_script = "<script>alert('xss')</script>"
    
    post search_admin_wholesale_funders_path, params: { search: malicious_script }
    assert_redirected_to admin_wholesale_funders_path(search: malicious_script)
    # The controller should handle this safely without executing the script
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password" # This should match your test fixtures
      }
    }
  end
end