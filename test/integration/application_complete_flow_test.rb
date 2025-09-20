require 'test_helper'

class ApplicationCompleteFlowTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:regular_user)
    @admin = users(:admin_user)
  end

  test "complete application flow with CoreLogic integration works end to end" do
    # Sign in user
    sign_in @user

    # Test 1: Create new application with CoreLogic property data
    post applications_path, params: {
      application: {
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
        property_images: JSON.generate([
          "https://example.com/property1.jpg",
          "https://example.com/property2.jpg"
        ]),
        corelogic_data: JSON.generate({
          property_id: "12345678",
          address: "123 Collins Street, Melbourne VIC 3000",
          valuation: {
            avm: {
              low_range_value: 1750000,
              high_range_value: 1850000
            }
          }
        })
      }
    }

    application = Application.last
    assert_equal "123 Collins Street, Melbourne VIC 3000", application.address
    assert_equal "12345678", application.property_id
    assert_equal 1800000, application.property_valuation_middle
    assert_response :redirect
    assert_redirected_to income_and_loan_application_path(application)

    # Test 2: Complete income and loan step
    mortgage = mortgages(:interest_only)
    patch update_income_and_loan_application_path(application), params: {
      application: {
        loan_term: 25,
        income_payout_term: 25,
        mortgage_id: mortgage.id,
        growth_rate: 3.5
      }
    }

    application.reload
    assert_equal 25, application.loan_term
    assert_equal mortgage.id, application.mortgage_id
    assert_response :redirect
    assert_redirected_to summary_application_path(application)

    # Test 3: Submit application
    patch submit_application_path(application)

    application.reload
    assert_equal "submitted", application.status
    assert_response :redirect
    assert_redirected_to congratulations_application_path(application)

    # Test 4: Admin can view complete application with property details
    sign_in @admin

    get admin_application_path(application)
    assert_response :success

    # Verify all the CoreLogic property details are displayed
    assert_response_body_contains("123 Collins Street, Melbourne VIC 3000")
    assert_response_body_contains("Property ID: 12345678")
    assert_response_body_contains("CoreLogic Valuation: $1,800,000")
    assert_response_body_contains("Range: $1,750,000 - $1,850,000")

    # Test 5: Admin can advance application to processing
    patch advance_to_processing_admin_application_path(application)

    application.reload
    assert_equal "processing", application.status

    # Verify checklist was auto-created
    assert application.application_checklists.exists?
    assert application.application_checklists.count > 0

    # Test 6: Admin can view application details and complete checklist
    get admin_application_path(application)
    assert_response :success

    # Complete all checklist items
    application.application_checklists.each do |item|
      patch update_checklist_item_admin_application_path(application), params: {
        checklist_item_id: item.id,
        completed: true
      }
    end

    application.reload
    assert application.checklist_completed?

    # Test 7: Admin can approve application (change to accepted)
    get edit_admin_application_path(application)
    assert_response :success

    patch admin_application_path(application), params: {
      application: {
        status: "accepted"
      }
    }

    application.reload
    assert_equal "accepted", application.status

    # Verify that the complete flow preserved all CoreLogic data
    assert_equal "12345678", application.property_id
    assert_equal "House", application.property_type
    assert_equal 2, application.property_images_array.length
    assert application.corelogic_property_data.key?("property_id")
    assert application.has_property_valuation?
  end

  test "autocomplete endpoints work correctly" do
    # Test authenticated access (autocomplete works for authenticated users)
    sign_in @user

    get autocomplete_applications_path, params: { query: 'Collins' }, as: :json
    assert_response :success

    suggestions = JSON.parse(response.body)
    assert suggestions.is_a?(Array)
    assert suggestions.length > 0

    # Test property details endpoint
    get get_property_details_applications_path, params: { property_id: '12345678' }, as: :json
    assert_response :success

    property_data = JSON.parse(response.body)
    assert property_data.is_a?(Hash)
    assert property_data.key?('address')
  end

  test "application form includes all necessary CoreLogic elements" do
    sign_in @user

    get new_application_path
    assert_response :success

    # Verify autocomplete structure is present
    assert_select 'form[data-controller*="property-autocomplete"]'
    assert_select 'input[data-property-autocomplete-target="input"]'
    assert_select 'div[data-property-autocomplete-target="suggestions"]'

    # Verify hidden CoreLogic fields
    assert_select 'input[name="application[property_id]"]', count: 1
    assert_select 'input[name="application[property_type]"]', count: 1
    assert_select 'input[name="application[property_images]"]', count: 1
    assert_select 'input[name="application[corelogic_data]"]', count: 1

    # Verify home value slider can be targeted by property autocomplete
    assert_select 'input[name="application[home_value]"][data-property-autocomplete-target="homeValue"]'
  end

  test "application model handles CoreLogic data correctly" do
    application = @user.applications.create!(
      address: "456 Test Street, Melbourne VIC 3000",
      home_value: 2000000,
      ownership_status: "individual",
      property_state: "primary_residence",
      has_existing_mortgage: false,
      borrower_age: 40,
      property_id: "TEST123",
      property_type: "Townhouse",
      property_valuation_low: 1950000,
      property_valuation_middle: 2000000,
      property_valuation_high: 2050000,
      property_images: JSON.generate([
        "https://example.com/image1.jpg",
        "https://example.com/image2.jpg",
        "https://example.com/image3.jpg"
      ]),
      corelogic_data: JSON.generate({
        property_id: "TEST123",
        address: "456 Test Street, Melbourne VIC 3000",
        attributes: {
          property_type: "Townhouse",
          bedrooms: 3,
          bathrooms: 2
        },
        valuation: {
          avm: {
            low_range_value: 1950000,
            high_range_value: 2050000
          }
        }
      })
    )

    # Test property images parsing
    images = application.property_images_array
    assert_equal 3, images.length
    assert_equal "https://example.com/image1.jpg", images.first

    # Test CoreLogic data parsing
    data = application.corelogic_property_data
    assert_equal "TEST123", data["property_id"]
    assert_equal 3, data.dig("attributes", "bedrooms")

    # Test valuation methods
    assert application.has_property_valuation?
    assert_equal "$2,000,000", application.formatted_property_valuation_middle
    assert_equal "$1,950,000 - $2,050,000", application.formatted_property_valuation_range
  end

  test "error handling works correctly for invalid data" do
    sign_in @user

    # Test with invalid property data
    post applications_path, params: {
      application: {
        address: "",  # Missing address
        home_value: -1000,  # Invalid value
        ownership_status: "individual",
        property_state: "primary_residence",
        borrower_age: 150  # Invalid age
      }
    }

    assert_response :unprocessable_entity

    # Should render the form again with errors
    # Check for error messages in the response body
    assert_includes response.body, "can't be blank"
  end

  private

  def assert_response_body_contains(text)
    assert_includes response.body, text, "Response body should contain '#{text}'"
  end
end