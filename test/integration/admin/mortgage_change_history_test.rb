require 'test_helper'

class Admin::MortgageChangeHistoryTest < ActionDispatch::IntegrationTest
  fixtures :users, :mortgages
  
  def setup
    @admin = users(:admin_user)
    @mortgage = mortgages(:basic_mortgage)
  end

  test "LVR changes appear in mortgage change history" do
    admin_sign_in
    
    # Update the mortgage LVR from 80.0 to 75.5
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 75.5
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    
    # Navigate to mortgage show page to see change history
    get admin_mortgage_path(@mortgage)
    assert_response :success
    
    # Verify change history section exists
    assert_select 'h3', text: 'Change History'
    
    # Verify LVR change is displayed with formatted values
    assert_select '.change-entry' do
      assert_select '.field-change' do |elements|
        lvr_change = elements.find { |el| el.text.include?('LVR:') }
        assert_not_nil lvr_change, "Should find LVR change in history"
        
        # Should show "80%" not "80.0%" for the old value
        assert_match /80%/, lvr_change.text
        assert_no_match /80\.0%/, lvr_change.text
        
        # Should show "75.5%" for the new value
        assert_match /75\.5%/, lvr_change.text
      end
    end
  end

  test "whole number to whole number LVR changes display correctly" do
    admin_sign_in
    
    # Update the mortgage LVR from 80.0 to 75.0 (both whole numbers)
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 75.0
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    
    # Navigate to mortgage show page to see change history
    get admin_mortgage_path(@mortgage)
    assert_response :success
    
    # Verify both values show without decimals
    assert_select '.change-entry' do
      assert_select '.field-change' do |elements|
        lvr_change = elements.find { |el| el.text.include?('LVR:') }
        assert_not_nil lvr_change, "Should find LVR change in history"
        
        # Should show "80%" and "75%" without decimals
        assert_match /80%/, lvr_change.text
        assert_match /75%/, lvr_change.text
        assert_no_match /80\.0%/, lvr_change.text
        assert_no_match /75\.0%/, lvr_change.text
      end
    end
  end

  test "multiple field changes including LVR are tracked" do
    admin_sign_in
    
    # Update multiple fields including LVR
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: "Updated Mortgage Name",
        mortgage_type: @mortgage.mortgage_type == 'interest_only' ? 'principal_and_interest' : 'interest_only',
        lvr: 82.5
      }
    }
    
    assert_redirected_to admin_mortgage_path(@mortgage)
    
    # Navigate to mortgage show page to see change history
    get admin_mortgage_path(@mortgage)
    assert_response :success
    
    # Verify multiple changes are shown
    assert_select '.field-change', minimum: 2 # Should have at least name and LVR changes
    
    # Verify LVR change is properly formatted
    assert_select '.field-change' do |elements|
      lvr_change = elements.find { |el| el.text.include?('LVR:') }
      assert_not_nil lvr_change
      assert_match /82\.5%/, lvr_change.text
    end
  end

  test "change history shows user who made the change" do
    admin_sign_in
    
    # Update the mortgage
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 85.0
      }
    }
    
    # Navigate to show page
    get admin_mortgage_path(@mortgage)
    assert_response :success
    
    # Verify admin user is shown as the one who made the change
    assert_select '.change-entry' do
      assert_select '.change-info' do
        assert_select 'strong', text: @admin.display_name
      end
    end
  end

  test "LVR validation errors do not create change history entries" do
    admin_sign_in
    
    # Count existing versions
    initial_versions = @mortgage.mortgage_versions.count
    
    # Try to update with invalid LVR (should fail validation)
    patch admin_mortgage_path(@mortgage), params: {
      mortgage: {
        name: @mortgage.name,
        mortgage_type: @mortgage.mortgage_type,
        lvr: 85.55 # Invalid - not in 0.1 increments
      }
    }
    
    assert_response :unprocessable_entity
    
    # Verify no new version was created
    @mortgage.reload
    assert_equal initial_versions, @mortgage.mortgage_versions.count
  end

  private

  def admin_sign_in
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
  end
end