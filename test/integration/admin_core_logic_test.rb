require 'test_helper'

class AdminCoreLogicTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user) # Assuming you have an admin user fixture
  end

  test "should redirect to login when not authenticated" do
    get admin_core_logic_test_index_path
    assert_redirected_to new_user_session_path
  end

  test "should show CoreLogic test page when authenticated as admin" do
    sign_in @admin_user
    get admin_core_logic_test_index_path
    assert_response :success
    assert_select 'h3', 'CoreLogic Property Search Test'
  end

  test "should handle property search" do
    sign_in @admin_user
    get search_admin_core_logic_test_index_path, params: { query: '123 Collins Street Melbourne' }
    assert_response :success
    # Should show search results in the page
    assert_select 'h3', text: /Search Results for/
  end

  test "should handle property details" do
    sign_in @admin_user
    get property_details_admin_core_logic_test_index_path, params: { property_id: '12345678' }
    assert_response :success
    # Should show property details sections
    assert_select 'h3', text: /Property Address|Property Attributes|Property Valuation/
  end

  test "should handle empty search query" do
    sign_in @admin_user
    get search_admin_core_logic_test_index_path, params: { query: '' }
    assert_redirected_to admin_core_logic_test_index_path
    assert_equal 'Please enter a search query', flash[:alert]
  end

  test "should handle missing property ID" do
    sign_in @admin_user
    get property_details_admin_core_logic_test_index_path, params: { property_id: '' }
    assert_redirected_to admin_core_logic_test_index_path
    assert_equal 'Property ID is required', flash[:alert]
  end
end