require 'test_helper'

class ApplicationCorelogicIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:regular_user)
    sign_in @user
  end

  test "should allow autocomplete for authenticated users" do
    get autocomplete_applications_path, params: { query: 'Collins' }, as: :json
    assert_response :success

    suggestions = JSON.parse(response.body)
    assert suggestions.is_a?(Array)
    assert suggestions.length > 0
  end

  test "should return empty array for short queries" do
    # Test with empty query
    get autocomplete_applications_path, params: { query: '' }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)

    # Test with 2 character query
    get autocomplete_applications_path, params: { query: 'Co' }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "should return formatted suggestions for valid queries" do
    get autocomplete_applications_path, params: { query: 'Collins' }, as: :json
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

  test "autocomplete endpoint should be accessible via AJAX" do
    get autocomplete_applications_path,
        params: { query: 'Melbourne' },
        headers: { 'X-Requested-With' => 'XMLHttpRequest' },
        as: :json

    assert_response :success
    assert_equal 'application/json; charset=utf-8', response.content_type

    suggestions = JSON.parse(response.body)
    assert suggestions.is_a?(Array)
  end

  test "should return property details for valid property ID" do
    get get_property_details_applications_path, params: { property_id: '12345678' }, as: :json
    assert_response :success

    property_data = JSON.parse(response.body)
    assert property_data.is_a?(Hash)
    assert property_data.key?('address')
    assert property_data.key?('attributes')
    assert property_data.key?('valuation')
  end

  test "should return error for missing property ID" do
    get get_property_details_applications_path, params: {}, as: :json
    assert_response :bad_request

    error_response = JSON.parse(response.body)
    assert_equal 'Property ID is required', error_response['error']
  end

  test "should create application with CoreLogic property data" do
    application_params = {
      address: "123 Collins Street, Melbourne VIC 3000",
      home_value: 1800000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 45,
      property_id: "12345678",
      property_type: "House",
      property_valuation_low: 1750000,
      property_valuation_middle: 1800000,
      property_valuation_high: 1850000,
      property_images: '["https://example.com/image1.jpg", "https://example.com/image2.jpg"]',
      corelogic_data: '{"property_id":"12345678","address":"123 Collins Street, Melbourne VIC 3000"}'
    }

    assert_difference 'Application.count' do
      post applications_path, params: { application: application_params }
    end

    application = Application.last
    assert_equal "123 Collins Street, Melbourne VIC 3000", application.address
    assert_equal "12345678", application.property_id
    assert_equal "House", application.property_type
    assert_equal 1800000, application.property_valuation_middle
    assert_equal 2, application.property_images_array.length
    assert application.corelogic_property_data.is_a?(Hash)

    assert_response :redirect
    assert_redirected_to income_and_loan_application_path(application)
  end

  test "application form should include property autocomplete functionality" do
    get new_application_path
    assert_response :success

    # Check that the form includes the autocomplete controller
    assert_select 'form[data-controller*="property-autocomplete"]'

    # Check that the address field has autocomplete attributes
    assert_select 'input[data-property-autocomplete-target="input"]'
    assert_select 'div[data-property-autocomplete-target="suggestions"]'

    # Check that hidden CoreLogic fields are present
    assert_select 'input[name="application[property_id]"]', count: 1
    assert_select 'input[name="application[property_type]"]', count: 1
    assert_select 'input[name="application[property_images]"]', count: 1
    assert_select 'input[name="application[corelogic_data]"]', count: 1
  end

  test "should update application with new property selection" do
    application = @user.applications.create!(
      address: "Initial Address",
      home_value: 1500000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 50
    )

    new_params = {
      address: "456 Swanston Street, Melbourne VIC 3000",
      home_value: 2100000,
      property_id: "87654321",
      property_type: "Apartment",
      property_valuation_middle: 2100000
    }

    patch application_path(application), params: { application: new_params }

    application.reload
    assert_equal "456 Swanston Street, Melbourne VIC 3000", application.address
    assert_equal "87654321", application.property_id
    assert_equal "Apartment", application.property_type
    assert_equal 2100000, application.property_valuation_middle

    assert_response :redirect
    assert_redirected_to income_and_loan_application_path(application)
  end

  test "should preserve CoreLogic data through form submission" do
    application_params = {
      address: "789 Collins Street, Melbourne VIC 3000",
      home_value: 2200000,
      ownership_status: "individual",
      property_state: "investment",
      has_existing_mortgage: true,
      existing_mortgage_amount: 800000,
      borrower_age: 55,
      property_id: "99887766",
      property_valuation_low: 2150000,
      property_valuation_middle: 2200000,
      property_valuation_high: 2250000,
      corelogic_data: JSON.generate({
        property_id: "99887766",
        address: "789 Collins Street, Melbourne VIC 3000",
        valuation: {
          avm: {
            low_range_value: 2150000,
            high_range_value: 2250000
          }
        }
      })
    }

    post applications_path, params: { application: application_params }

    application = Application.last
    assert_equal "99887766", application.property_id
    assert_equal 2200000, application.property_valuation_middle

    # Check that CoreLogic data was preserved and can be parsed
    parsed_data = application.corelogic_property_data
    assert_equal "99887766", parsed_data["property_id"]
    assert_equal 2150000, parsed_data.dig("valuation", "avm", "low_range_value")
  end

  test "admin should see property details and images in application view" do
    admin = users(:admin_user)
    sign_in admin

    application = @user.applications.create!(
      address: "100 Property Street, Melbourne VIC 3000",
      home_value: 1900000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 40,
      property_id: "PROP123456",
      property_type: "Townhouse",
      property_valuation_low: 1850000,
      property_valuation_middle: 1900000,
      property_valuation_high: 1950000,
      property_images: JSON.generate([
        "https://example.com/property1.jpg",
        "https://example.com/property2.jpg"
      ])
    )

    get admin_application_path(application)
    assert_response :success

    # Check that property ID is displayed
    assert_select 'small.property-id', text: /PROP123456/

    # Check that valuation info is displayed
    assert_select 'small.valuation-info', text: /CoreLogic Valuation/
    assert_select 'small.valuation-info em', text: /Range/

    # Check that property images are displayed
    assert_select '.property-images-grid'
    assert_select '.property-image', count: 2
  end
end