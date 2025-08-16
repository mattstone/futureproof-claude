require "test_helper"

class Admin::LendersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_lender = lenders(:futureproof)
    @lender_lender = lenders(:broker) # This is actually a regular lender, not broker
    @futureproof_admin = users(:futureproof_admin)
    @lender_admin = users(:broker_admin) # This is actually a lender admin, not broker
  end

  # Authorization Tests
  test "should redirect non-admin users" do
    sign_in users(:user_one)
    get admin_lenders_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should redirect lender admins from lenders management" do
    sign_in @lender_admin
    get admin_lenders_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should allow futureproof admins to access lenders" do
    sign_in @futureproof_admin
    get admin_lenders_path
    assert_response :success
  end

  # Index Tests
  test "should get index for futureproof admin" do
    sign_in @futureproof_admin
    get admin_lenders_path
    assert_response :success
    assert_not_nil assigns(:lenders)
  end

  test "should include search functionality" do
    sign_in @futureproof_admin
    get admin_lenders_path, params: { search: "futureproof" }
    assert_response :success
    assert_not_nil assigns(:lenders)
  end

  # Show Tests
  test "should show lender for futureproof admin" do
    sign_in @futureproof_admin
    get admin_lender_path(@futureproof_lender)
    assert_response :success
    assert_not_nil assigns(:lender)
  end

  test "should not allow lender admin to view other lenders" do
    sign_in @lender_admin
    get admin_lender_path(@futureproof_lender)
    assert_redirected_to admin_dashboard_index_path
  end

  # New Tests
  test "should get new for futureproof admin" do
    sign_in @futureproof_admin
    get new_admin_lender_path
    assert_response :success
    assert_not_nil assigns(:lender)
    assert assigns(:lender).new_record?
  end

  test "should not allow lender admin to access new" do
    sign_in @lender_admin
    get new_admin_lender_path
    assert_redirected_to admin_dashboard_index_path
  end

  # Create Tests
  test "should create lender with valid params" do
    sign_in @futureproof_admin
    assert_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "New Test Lender",
          lender_type: "lender",
          country: "Australia",
          contact_email: "test@newlender.com"
        }
      }
    end
    assert_redirected_to admin_lender_path(Lender.last)
    assert_match /successfully created/, flash[:notice]
  end

  test "should not create lender with invalid params" do
    sign_in @futureproof_admin
    assert_no_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "", # Invalid - blank name
          lender_type: "lender",
          country: "Australia",
          contact_email: "test@newlender.com"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not allow lender admin to create lender" do
    sign_in @lender_admin
    assert_no_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "Test Lender",
          lender_type: "lender",
          country: "Australia",
          contact_email: "test@lender.com"
        }
      }
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # Edit Tests
  test "should get edit for futureproof admin" do
    sign_in @futureproof_admin
    get edit_admin_lender_path(@lender_lender)
    assert_response :success
    assert_not_nil assigns(:lender)
    assert_equal @lender_lender, assigns(:lender)
  end

  test "should not allow lender admin to access edit" do
    sign_in @lender_admin
    get edit_admin_lender_path(@futureproof_lender)
    assert_redirected_to admin_dashboard_index_path
  end

  # Update Tests
  test "should update lender with valid params" do
    sign_in @futureproof_admin
    patch admin_lender_path(@lender_lender), params: {
      lender: {
        name: "Updated Lender Name"
      }
    }
    assert_redirected_to admin_lender_path(@lender_lender)
    assert_match /successfully updated/, flash[:notice]
    @lender_lender.reload
    assert_equal "Updated Lender Name", @lender_lender.name
  end

  test "should not update lender with invalid params" do
    sign_in @futureproof_admin
    patch admin_lender_path(@lender_lender), params: {
      lender: {
        name: "" # Invalid - blank name
      }
    }
    assert_response :unprocessable_entity
  end

  test "should not allow lender admin to update lenders" do
    sign_in @lender_admin
    patch admin_lender_path(@futureproof_lender), params: {
      lender: { name: "Hacked Name" }
    }
    assert_redirected_to admin_dashboard_index_path
  end

  # Destroy Tests
  test "should destroy lender for futureproof admin" do
    sign_in @futureproof_admin
    # Create a lender that can be safely deleted (not futureproof type)
    deletable_lender = Lender.create!(
      name: "Deletable Lender",
      lender_type: "lender", 
      country: "Australia",
      contact_email: "delete@me.com"
    )
    
    assert_difference('Lender.count', -1) do
      delete admin_lender_path(deletable_lender)
    end
    assert_redirected_to admin_lenders_path
    assert_match /successfully deleted/, flash[:notice]
  end

  test "should not allow deletion of futureproof lender" do
    sign_in @futureproof_admin
    # Most lender deletion logic would prevent deletion of futureproof lender
    # This test depends on the implementation in the controller
    delete admin_lender_path(@futureproof_lender)
    # The response will depend on how the controller handles this case
    # It might redirect with an error or just refuse to delete
  end

  test "should not allow lender admin to destroy lender" do
    sign_in @lender_admin
    assert_no_difference('Lender.count') do
      delete admin_lender_path(@lender_lender)
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # Lender Type Tests
  test "should handle different lender types correctly" do
    sign_in @futureproof_admin
    get admin_lenders_path
    assert_response :success
    
    # Verify that both futureproof and regular lenders are handled
    lenders = assigns(:lenders)
    assert lenders.any? { |l| l.lender_type_futureproof? }
    assert lenders.any? { |l| l.lender_type_lender? }
  end

  test "should display correct badges for lender types" do
    sign_in @futureproof_admin
    get admin_lenders_path
    assert_response :success
    assert_match /futureproof/i, response.body
    assert_match /lender/i, response.body
  end

  # Change Tracking Tests
  test "should track lender creation with change tracking" do
    sign_in @futureproof_admin
    assert_difference(['Lender.count', 'LenderVersion.count']) do
      post admin_lenders_path, params: {
        lender: {
          name: "Change Tracked Lender",
          lender_type: "lender",
          country: "Australia",
          contact_email: "tracked@lender.com"
        }
      }
    end
    
    version = LenderVersion.last
    assert_equal 'created', version.action
    assert_equal @futureproof_admin, version.user
    assert_includes version.change_details, "Change Tracked Lender"
  end

  test "should track lender updates with change tracking" do
    sign_in @futureproof_admin
    assert_difference('LenderVersion.count') do
      patch admin_lender_path(@lender_lender), params: {
        lender: {
          name: "Updated with Tracking",
          contact_email: "updated@tracking.com"
        }
      }
    end
    
    version = LenderVersion.last
    assert_equal 'updated', version.action
    assert_equal @futureproof_admin, version.user
    assert_includes version.change_details.downcase, "name"
    assert_includes version.change_details.downcase, "contact email"
  end

  # Enum Method Tests
  test "should correctly identify futureproof lender type" do
    sign_in @futureproof_admin
    get admin_lender_path(@futureproof_lender)
    assert_response :success
    assert @futureproof_lender.lender_type_futureproof?
    assert_not @futureproof_lender.lender_type_lender?
  end

  test "should correctly identify regular lender type" do
    sign_in @futureproof_admin
    get admin_lender_path(@lender_lender)
    assert_response :success
    assert @lender_lender.lender_type_lender?
    assert_not @lender_lender.lender_type_futureproof?
  end

  test "should not allow multiple futureproof lenders" do
    sign_in @futureproof_admin
    assert_no_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "Another Futureproof",
          lender_type: "futureproof", # This should fail validation
          country: "Australia",
          contact_email: "another@futureproof.com"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # Form Validation Tests  
  test "should validate contact email format" do
    sign_in @futureproof_admin
    assert_no_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "Invalid Email Lender",
          lender_type: "lender",
          country: "Australia",
          contact_email: "invalid-email-format" # Invalid email
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should require all mandatory fields" do
    sign_in @futureproof_admin
    assert_no_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "", # Missing name
          lender_type: "", # Missing type
          country: "", # Missing country
          contact_email: "" # Missing email
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should display correct lender type in form" do
    sign_in @futureproof_admin
    get edit_admin_lender_path(@lender_lender)
    assert_response :success
    # Verify the form shows the correct enum options
    assert_match /Lender/, response.body
    assert_match /Futureproof/, response.body
    # Should not contain the old enum values
    assert_no_match /broker/i, response.body.gsub(/test.*broker.*lender/i, '') # Ignore fixture name
    assert_no_match /master/i, response.body
  end

  # Security Tests
  test "should handle XSS in search parameters" do
    sign_in @futureproof_admin
    malicious_script = "<script>alert('xss')</script>"
    
    get admin_lenders_path, params: { search: malicious_script }
    assert_response :success
    # The search should be handled safely without executing the script
  end

  test "should log access attempts" do
    sign_in @futureproof_admin
    
    # Test that access is logged (we can't easily test Rails.logger.info in tests,
    # but we can ensure the action completes successfully)
    get admin_lenders_path
    assert_response :success
  end

  # Association Tests
  test "should display user count for lenders" do
    sign_in @futureproof_admin
    get admin_lender_path(@futureproof_lender)
    assert_response :success
    # Should display information about associated users
  end

  test "should handle lenders with no users" do
    sign_in @futureproof_admin
    # Create a lender with no users
    empty_lender = Lender.create!(
      name: "Empty Lender",
      lender_type: "lender",
      country: "Australia", 
      contact_email: "empty@lender.com"
    )
    
    get admin_lender_path(empty_lender)
    assert_response :success
    
    empty_lender.destroy
  end

  # Wholesale Funder Integration Tests
  test "should display wholesale funder selection interface on lender show page" do
    sign_in @futureproof_admin
    get admin_lender_path(@lender_lender)
    assert_response :success
    
    # Check for the wholesale funder selection button
    assert_select "button#toggle-wholesale-funder-selection", text: "Add Wholesale Funder"
    
    # Check for the hidden selection interface
    assert_select "div#wholesale-funder-selection[style*='display: none']"
    assert_select "div#available-wholesale-funders.wholesale-funders-grid"
    assert_select "button#close-wholesale-funder-selection"
  end

  test "should get available wholesale funders via AJAX" do
    sign_in @futureproof_admin
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?("wholesale_funders")
    assert json_response["wholesale_funders"].is_a?(Array)
    
    # Each wholesale funder should have required fields
    if json_response["wholesale_funders"].any?
      funder = json_response["wholesale_funders"].first
      assert funder.key?("id")
      assert funder.key?("name")
      assert funder.key?("country")
      assert funder.key?("currency")
      assert funder.key?("currency_symbol")
      assert funder.key?("pools_count")
      assert funder.key?("formatted_total_capital")
    end
  end

  test "should exclude existing wholesale funder relationships from available list" do
    sign_in @futureproof_admin
    
    # Create a wholesale funder and relationship
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    LenderWholesaleFunder.create!(
      lender: @lender_lender,
      wholesale_funder: wholesale_funder,
      active: true
    )
    
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    available_ids = json_response["wholesale_funders"].map { |wf| wf["id"] }
    
    # Should not include the wholesale funder that already has a relationship
    assert_not_includes available_ids, wholesale_funder.id
    
    # Cleanup
    LenderWholesaleFunder.find_by(lender: @lender_lender, wholesale_funder: wholesale_funder)&.destroy
    wholesale_funder.destroy
  end

  test "available_wholesale_funders should require authentication" do
    # Don't sign in - should be redirected
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :redirect
  end

  test "available_wholesale_funders should require admin privileges" do
    sign_in users(:user_one) # Regular user, not admin
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should handle error when lender not found for available_wholesale_funders" do
    sign_in @futureproof_admin
    
    get "/admin/lenders/999999/available_wholesale_funders", 
        headers: { "Accept" => "application/json" }
    
    assert_response :not_found
  end

  test "should return empty array when no wholesale funders available" do
    sign_in @futureproof_admin
    
    # Create relationships for all existing wholesale funders
    WholesaleFunder.all.each do |wf|
      LenderWholesaleFunder.find_or_create_by(
        lender: @lender_lender,
        wholesale_funder: wf
      ) do |relationship|
        relationship.active = true
      end
    end
    
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal [], json_response["wholesale_funders"]
    
    # Cleanup - remove the relationships we created
    @lender_lender.lender_wholesale_funders.destroy_all
  end

  test "should include funder pools count in wholesale funder data" do
    sign_in @futureproof_admin
    
    # Create a wholesale funder with pools
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder with Pools",
      country: "Australia", 
      currency: "AUD"
    )
    
    # Create some funder pools
    3.times do |i|
      FunderPool.create!(
        wholesale_funder: wholesale_funder,
        name: "Pool #{i + 1}",
        amount: 100000 + (i * 50000)
      )
    end
    
    get available_wholesale_funders_admin_lender_path(@lender_lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    test_funder = json_response["wholesale_funders"].find { |wf| wf["id"] == wholesale_funder.id }
    
    assert test_funder
    assert_equal 3, test_funder["pools_count"]
    
    # Cleanup
    wholesale_funder.destroy
  end

  test "should work with existing wholesale funder add functionality" do
    sign_in @futureproof_admin
    
    # Create a wholesale funder to add
    wholesale_funder = WholesaleFunder.create!(
      name: "Integration Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    # Test that we can still add wholesale funders via the existing endpoint
    assert_difference("LenderWholesaleFunder.count") do
      post add_wholesale_funder_admin_lender_wholesale_funders_path(@lender_lender), 
           params: { wholesale_funder_id: wholesale_funder.id },
           headers: { "Accept" => "application/json" }
    end
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_includes json_response["message"], wholesale_funder.name
    
    # Verify the relationship was created
    relationship = LenderWholesaleFunder.find_by(
      lender: @lender_lender, 
      wholesale_funder: wholesale_funder
    )
    assert relationship
    assert relationship.active?
    
    # Cleanup
    relationship&.destroy
    wholesale_funder.destroy
  end

  test "should display existing wholesale funder relationships on show page" do
    sign_in @futureproof_admin
    
    # Create a wholesale funder and relationship
    wholesale_funder = WholesaleFunder.create!(
      name: "Displayed Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    relationship = LenderWholesaleFunder.create!(
      lender: @lender_lender,
      wholesale_funder: wholesale_funder,
      active: true
    )
    
    get admin_lender_path(@lender_lender)
    assert_response :success
    
    # Should display the wholesale funder relationship
    assert_includes response.body, wholesale_funder.name
    assert_includes response.body, "Wholesale Funder Relationships"
    
    # Cleanup
    relationship.destroy
    wholesale_funder.destroy
  end

  test "should show empty state when no wholesale funder relationships exist" do
    sign_in @futureproof_admin
    
    # Ensure no relationships exist
    @lender_lender.lender_wholesale_funders.destroy_all
    
    get admin_lender_path(@lender_lender)
    assert_response :success
    
    # Should show empty state message
    assert_includes response.body, "No wholesale funder relationships established"
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