require "test_helper"

class Admin::MortgagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_lender = lenders(:futureproof)
    @broker_lender = lenders(:broker)
    @futureproof_admin = users(:futureproof_admin)
    @broker_admin = users(:broker_admin)
    @mortgage = mortgages(:basic_mortgage)
  end

  # Authorization Tests
  test "should redirect non-admin users" do
    sign_in users(:user_one)
    get admin_mortgages_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should redirect broker admins from mortgages management" do
    sign_in @broker_admin
    get admin_mortgages_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should allow futureproof admins to access mortgages" do
    sign_in @futureproof_admin
    get admin_mortgages_path
    assert_response :success
  end

  # Index Tests
  test "should get index for futureproof admin" do
    sign_in @futureproof_admin
    get admin_mortgages_path
    assert_response :success
    assert_not_nil assigns(:mortgages)
  end

  test "should include search functionality" do
    sign_in @futureproof_admin
    get admin_mortgages_path, params: { search: "basic" }
    assert_response :success
    assert_not_nil assigns(:mortgages)
  end

  # Show Tests
  test "should show mortgage for futureproof admin" do
    sign_in @futureproof_admin
    get admin_mortgage_path(@mortgage)
    assert_response :success
    assert_not_nil assigns(:mortgage)
  end

  test "should not allow broker admin to view mortgages" do
    sign_in @broker_admin
    get admin_mortgage_path(@mortgage)
    assert_redirected_to admin_dashboard_index_path
  end

  # New Tests
  test "should get new for futureproof admin" do
    sign_in @futureproof_admin
    get new_admin_mortgage_path
    assert_response :success
    assert_not_nil assigns(:mortgage)
    assert assigns(:mortgage).new_record?
  end

  test "should not allow broker admin to access new" do
    sign_in @broker_admin
    get new_admin_mortgage_path
    assert_redirected_to admin_dashboard_index_path
  end

  # Create Tests
  test "should create mortgage with valid params" do
    sign_in @futureproof_admin
    assert_difference('Mortgage.count') do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "New Test Mortgage",
          mortgage_type: "interest_only",
          lvr: 75.5,
          lender_id: @futureproof_lender.id
        }
      }
    end
    assert_redirected_to admin_mortgage_path(Mortgage.last)
    assert_match /successfully created/, flash[:notice]
    
    created_mortgage = Mortgage.last
    assert_equal @futureproof_lender, created_mortgage.lender
  end

  test "should not create mortgage with invalid params" do
    sign_in @futureproof_admin
    assert_no_difference('Mortgage.count') do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "", # Invalid - blank name
          mortgage_type: "interest_only",
          lvr: 75.5
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not allow broker admin to create mortgage" do
    sign_in @broker_admin
    assert_no_difference('Mortgage.count') do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "Test Mortgage",
          mortgage_type: "interest_only",
          lvr: 75.5
        }
      }
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # Edit Tests
  test "should get edit for futureproof admin" do
    sign_in @futureproof_admin
    get edit_admin_mortgage_path(@mortgage)
    assert_response :success
    assert_not_nil assigns(:mortgage)
    assert_equal @mortgage, assigns(:mortgage)
  end

  test "should not allow broker admin to access edit" do
    sign_in @broker_admin
    get edit_admin_mortgage_path(@mortgage)
    assert_redirected_to admin_dashboard_index_path
  end

  # Update Tests
  test "should update mortgage with valid params" do
    sign_in @futureproof_admin
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: "Updated Mortgage Name",
        lvr: 80.0
      }
    }
    assert_redirected_to admin_mortgage_path(@mortgage)
    assert_match /successfully updated/, flash[:notice]
    @mortgage.reload
    assert_equal "Updated Mortgage Name", @mortgage.name
    assert_equal 80.0, @mortgage.lvr
  end

  test "should not update mortgage with invalid params" do
    sign_in @futureproof_admin
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: "", # Invalid - blank name
        lvr: 150.0 # Invalid - over 100%
      }
    }
    assert_response :unprocessable_entity
  end

  test "should not allow broker admin to update mortgages" do
    sign_in @broker_admin
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: { name: "Hacked Name" }
    }
    assert_redirected_to admin_dashboard_index_path
  end

  # Destroy Tests
  test "should destroy mortgage for futureproof admin" do
    sign_in @futureproof_admin
    # Create a mortgage that can be safely deleted
    deletable_mortgage = Mortgage.create!(
      name: "Deletable Mortgage",
      mortgage_type: "interest_only",
      lvr: 80.0
    )
    
    assert_difference('Mortgage.count', -1) do
      delete admin_mortgage_path(deletable_mortgage)
    end
    assert_redirected_to admin_mortgages_path
    assert_match /successfully deleted/, flash[:notice]
  end

  test "should not allow broker admin to destroy mortgage" do
    sign_in @broker_admin
    assert_no_difference('Mortgage.count') do
      delete admin_mortgage_path(@mortgage)
    end
    assert_redirected_to admin_dashboard_index_path
  end

  # LVR Validation Tests
  test "should validate LVR increments on update" do
    sign_in @futureproof_admin
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        lvr: 75.55 # Invalid - not in 0.1 increments
      }
    }
    assert_response :unprocessable_entity
    assert_match /must be in increments of 0.1/, response.body
  end

  test "should accept valid LVR values" do
    sign_in @futureproof_admin
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        lvr: 75.5 # Valid - in 0.1 increments
      }
    }
    assert_redirected_to admin_mortgage_path(@mortgage)
  end

  # Mortgage Type Tests
  test "should handle different mortgage types correctly" do
    sign_in @futureproof_admin
    
    # Test Interest Only
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: { mortgage_type: "interest_only" }
    }
    assert_redirected_to admin_mortgage_path(@mortgage)
    
    # Test Principal and Interest
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: { mortgage_type: "principal_and_interest" }
    }
    assert_redirected_to admin_mortgage_path(@mortgage)
  end

  # Security Tests
  test "should handle XSS in search parameters" do
    sign_in @futureproof_admin
    malicious_script = "<script>alert('xss')</script>"
    
    get admin_mortgages_path, params: { search: malicious_script }
    assert_response :success
    # The search should be handled safely without executing the script
  end

  # Lender Association Tests
  test "should create mortgage without lender" do
    sign_in @futureproof_admin
    assert_difference('Mortgage.count') do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "New Test Mortgage Without Lender",
          mortgage_type: "interest_only",
          lvr: 75.5
        }
      }
    end
    assert_redirected_to admin_mortgage_path(Mortgage.last)
    
    created_mortgage = Mortgage.last
    assert_nil created_mortgage.lender
  end

  test "should update mortgage lender" do
    sign_in @futureproof_admin
    
    # Create mortgage without lender
    mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: "interest_only",
      lvr: 80.0
    )
    
    patch admin_mortgage_path(mortgage), params: {
      mortgage: {
        lender_id: @broker_lender.id
      }
    }
    assert_redirected_to admin_mortgage_path(mortgage)
    
    mortgage.reload
    assert_equal @broker_lender, mortgage.lender
  end

  test "should display lender information on show page" do
    sign_in @futureproof_admin
    
    # Create mortgage with lender
    mortgage = Mortgage.create!(
      name: "Test Mortgage with Lender",
      mortgage_type: "interest_only",
      lvr: 80.0,
      lender: @futureproof_lender
    )
    
    get admin_mortgage_path(mortgage)
    assert_response :success
    assert_includes response.body, @futureproof_lender.name
  end

  test "should handle mortgages with no lender" do
    sign_in @futureproof_admin
    # Create a mortgage with no lender
    empty_mortgage = Mortgage.create!(
      name: "Empty Mortgage",
      mortgage_type: "interest_only",
      lvr: 80.0
    )
    
    get admin_mortgage_path(empty_mortgage)
    assert_response :success
    assert_includes response.body, "No lender assigned"
    
    empty_mortgage.destroy
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