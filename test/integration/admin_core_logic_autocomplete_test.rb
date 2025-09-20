require 'test_helper'

class AdminCoreLogicAutocompleteTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user)
  end

  test "should require authentication for autocomplete endpoint" do
    get autocomplete_admin_core_logic_test_index_path, params: { query: 'Collins' }
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should return empty array for short queries" do
    sign_in @admin_user

    # Test with empty query
    get autocomplete_admin_core_logic_test_index_path, params: { query: '' }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)

    # Test with 2 character query
    get autocomplete_admin_core_logic_test_index_path, params: { query: 'Co' }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "should return formatted suggestions for valid queries" do
    sign_in @admin_user

    get autocomplete_admin_core_logic_test_index_path, params: { query: 'Collins' }, as: :json
    assert_response :success

    suggestions = JSON.parse(response.body)
    assert suggestions.is_a?(Array)
    assert suggestions.length > 0

    # Check the structure of the first suggestion
    first_suggestion = suggestions.first
    assert first_suggestion.key?('id')
    assert first_suggestion.key?('text')
    assert first_suggestion.key?('property_type')
    assert first_suggestion.key?('is_active')
    assert first_suggestion.key?('is_unit')

    # Verify the content
    assert_equal '12345678', first_suggestion['id']
    assert_match(/Collins/, first_suggestion['text'])
    assert_equal 'Property', first_suggestion['property_type']
  end

  test "should handle different property types in suggestions" do
    sign_in @admin_user

    get autocomplete_admin_core_logic_test_index_path, params: { query: 'Collins' }, as: :json
    assert_response :success

    suggestions = JSON.parse(response.body)

    # Should have both Property and Unit types from mock data
    property_types = suggestions.map { |s| s['property_type'] }.uniq
    assert_includes property_types, 'Property'
    assert_includes property_types, 'Unit'

    # Should have both active and inactive properties (nil counts as inactive)
    active_statuses = suggestions.map { |s| s['is_active'] }.uniq
    assert_includes active_statuses, true
    # One of the mock suggestions has nil for is_active (which is falsy)
    assert active_statuses.include?(nil) || active_statuses.include?(false)
  end

  test "autocomplete endpoint should be accessible via AJAX" do
    sign_in @admin_user

    get autocomplete_admin_core_logic_test_index_path,
        params: { query: 'Melbourne' },
        headers: { 'X-Requested-With' => 'XMLHttpRequest' },
        as: :json

    assert_response :success
    assert_equal 'application/json; charset=utf-8', response.content_type

    suggestions = JSON.parse(response.body)
    assert suggestions.is_a?(Array)
  end

  test "should return valid JSON content type" do
    sign_in @admin_user

    get autocomplete_admin_core_logic_test_index_path, params: { query: 'Test' }, as: :json
    assert_response :success
    assert_match /application\/json/, response.content_type
  end
end