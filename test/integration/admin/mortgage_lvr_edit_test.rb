require 'test_helper'

class Admin::MortgageLvrEditTest < ActionDispatch::IntegrationTest
  fixtures :users, :mortgages
  
  def setup
    @admin = users(:admin_user)
    @mortgage = mortgages(:basic_mortgage)
  end

  test "admin can edit mortgage LVR field" do
    admin_sign_in
    
    # Navigate to mortgage edit page
    get edit_admin_mortgage_path(@mortgage)
    assert_response :success
    
    # Verify LVR field is present and editable
    assert_select 'input[name="mortgage[lvr]"]' do |elements|
      element = elements.first
      assert_equal 'number', element['type']
      assert_equal '0.1', element['step']
      assert_equal '1', element['min']
      assert_equal '100', element['max']
      assert_equal 'required', element['required']
    end
    
    # Verify field hint shows correct range and increments
    assert_select 'small.field-hint', text: /1-100.*increments of 0.1/
  end

  test "admin can update mortgage with valid LVR" do
    admin_sign_in
    
    # Update mortgage with valid LVR
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 85.5
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    
    # Verify LVR was updated
    @mortgage.reload
    assert_equal 85.5, @mortgage.lvr
  end

  test "admin cannot update mortgage with invalid LVR increments" do
    admin_sign_in
    
    # Try to update with invalid increment
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 85.55  # Invalid - not in 0.1 increments
      }
    }
    
    assert_response :unprocessable_entity
    
    # Verify error message is displayed
    assert_select '.alert-danger' do
      assert_select 'li', text: /must be in increments of 0.1/
    end
    
    # Verify LVR was not updated
    @mortgage.reload
    assert_not_equal 85.55, @mortgage.lvr
  end

  test "admin cannot update mortgage with LVR below 1" do
    admin_sign_in
    
    # Try to update with LVR below minimum
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 0.5
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.alert-danger' do
      assert_select 'li', text: /must be greater than or equal to 1/
    end
  end

  test "admin cannot update mortgage with LVR above 100" do
    admin_sign_in
    
    # Try to update with LVR above maximum
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 101.0
      }
    }
    
    assert_response :unprocessable_entity
    assert_select '.alert-danger' do
      assert_select 'li', text: /must be less than or equal to 100/
    end
  end

  test "admin can create new mortgage with valid LVR" do
    admin_sign_in
    
    # Navigate to new mortgage page
    get new_admin_mortgage_path
    assert_response :success
    
    # Verify form has correct LVR field attributes
    assert_select 'input[name="mortgage[lvr]"]' do |elements|
      element = elements.first
      assert_equal '0.1', element['step']
      assert_equal '1', element['min']
      assert_equal '100', element['max']
      assert_equal '80.0', element['value']  # Default value
    end
    
    # Create new mortgage with valid LVR
    assert_difference 'Mortgage.count', 1 do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "New Test Mortgage",
          mortgage_type: "interest_only",
          lvr: 75.3
        }
      }
    end
    
    new_mortgage = Mortgage.last
    assert_equal 75.3, new_mortgage.lvr
    assert_equal "interest_only", new_mortgage.mortgage_type
  end

  test "admin cannot create new mortgage with invalid LVR" do
    admin_sign_in
    
    # Try to create mortgage with invalid LVR
    assert_no_difference 'Mortgage.count' do
      post admin_mortgages_path, params: {
        mortgage: {
          name: "Invalid LVR Mortgage",
          mortgage_type: "interest_only",
          lvr: 75.33  # Invalid increment
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select '.alert-danger' do
      assert_select 'li', text: /must be in increments of 0.1/
    end
  end

  test "admin can see LVR in mortgages index" do
    admin_sign_in
    
    # Navigate to mortgages index
    get admin_mortgages_path
    assert_response :success
    
    # Verify LVR column header is present
    assert_select 'th', text: 'LVR'
    
    # Verify LVR values are displayed for each mortgage
    assert_select 'td strong', text: /\d+\.?\d*%/
  end

  test "LVR display formatting works correctly in views" do
    admin_sign_in
    
    # Create mortgage with whole number LVR
    whole_number_mortgage = Mortgage.create!(
      name: "Whole Number LVR Test",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    # Create mortgage with decimal LVR
    decimal_mortgage = Mortgage.create!(
      name: "Decimal LVR Test", 
      mortgage_type: :principal_and_interest,
      lvr: 75.5
    )
    
    # Test index view
    get admin_mortgages_path
    assert_response :success
    
    # Should show "80%" not "80.0%"
    assert_match /80%/, response.body
    assert_no_match /80\.0%/, response.body
    
    # Should show "75.5%" 
    assert_match /75\.5%/, response.body
    
    # Test show view for whole number
    get admin_mortgage_path(whole_number_mortgage)
    assert_response :success
    assert_match /80%/, response.body
    assert_no_match /80\.0%/, response.body
    
    # Test show view for decimal
    get admin_mortgage_path(decimal_mortgage)
    assert_response :success
    assert_match /75\.5%/, response.body
  end

  test "LVR boundary values work correctly" do
    admin_sign_in
    
    # Test minimum boundary (1.0)
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 1.0
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    @mortgage.reload
    assert_equal 1.0, @mortgage.lvr
    
    # Test maximum boundary (100.0)
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 100.0
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    @mortgage.reload
    assert_equal 100.0, @mortgage.lvr
  end

  private

  def admin_sign_in
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
  end
end