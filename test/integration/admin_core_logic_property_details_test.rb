require 'test_helper'

class AdminCoreLogicPropertyDetailsTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user) # Assuming you have an admin user fixture
  end

  test "property details page renders completely without errors" do
    sign_in @admin_user

    # Test with a mock property ID that will use our mock data
    get property_details_admin_core_logic_test_index_path, params: { property_id: '12345678' }

    assert_response :success

    # Check that all main sections are rendered
    assert_select 'h3', text: /Property Address/
    assert_select 'h3', text: /Property Attributes/
    assert_select 'h3', text: /Property Valuation/
    assert_select 'h3', text: /Property Images/

    # Check that property data is present in the page
    assert_match /Collins Street/, response.body
    assert_match /Apartment/, response.body
    assert_match /750/, response.body

    # Check that images section renders
    assert_select '.property-images-grid'
    assert_select '.property-image-card'

    # Verify no errors in the response
    assert_no_match /Error|Exception|undefined/, response.body
  end

  test "property details page handles missing property gracefully" do
    sign_in @admin_user

    # Test with missing property_id parameter
    get property_details_admin_core_logic_test_index_path, params: { property_id: '' }

    # Should redirect back to index with error message
    assert_redirected_to admin_core_logic_test_index_path
    follow_redirect!

    assert_select '.alert', text: /Property ID is required/
  end
end