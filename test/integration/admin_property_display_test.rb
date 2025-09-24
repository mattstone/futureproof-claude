require "test_helper"

class AdminPropertyDisplayTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user)
    sign_in @admin_user

    # Find or create an application with CoreLogic data for testing
    @application = Application.where.not(corelogic_data: [nil, '']).first

    # If no application with CoreLogic data exists, create one
    if @application.nil?
      @application = applications(:mortgage_application)
      @application.update!(
        corelogic_data: {
          land_area: "600",
          building_area: "180",
          year_built: "2015",
          bedrooms: "3",
          bathrooms: "2",
          parking_spaces: "2"
        }.to_json,
        property_images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"].to_json,
        property_type: "house",
        property_id: "CL123456",
        property_valuation_low: 1800000,
        property_valuation_middle: 2000000,
        property_valuation_high: 2200000
      )
    end
  end

  test "admin can view application edit page with CoreLogic data" do
    # Visit the admin application edit page
    get edit_admin_application_path(@application)
    assert_response :success
    assert_select "h2", text: "Application ##{@application.id}"

    # Verify property section is present
    assert_select "h4", text: "Property Information"

    # Verify property valuation is displayed
    if @application.has_property_valuation?
      assert_select ".property-valuation-details"
      assert_select ".valuation-primary"
    end

    # Verify property type is displayed if present
    if @application.property_type.present?
      assert_select ".detail-row", text: /Property Type:/
    end

    # Property ID field has been removed

    # Verify CoreLogic data fields are displayed if present
    if @application.corelogic_data_hash['land_area'].present?
      assert_select ".detail-row", text: /Land Area:/
    end

    if @application.corelogic_data_hash['building_area'].present?
      assert_select ".detail-row", text: /Building Area:/
    end

    if @application.corelogic_data_hash['year_built'].present?
      assert_select ".detail-row", text: /Year Built:/
    end

    # Verify image switching functionality is present if there are multiple images
    if @application.property_images_array.length > 1
      assert_select "[data-controller='admin-property-gallery']"
      assert_select "[data-admin-property-gallery-target='primaryImage']"
      assert_select "[data-admin-property-gallery-target='thumbnail']"
      assert_select "[data-action='click->admin-property-gallery#selectImage']"
    end

    puts "✅ Admin edit page successfully displays property data!"
    puts "   - Application ID: #{@application.id}"
    puts "   - Property Type: #{@application.property_type}" if @application.property_type.present?
    puts "   - Has Valuation: #{@application.has_property_valuation?}"
    puts "   - Has Images: #{@application.property_images_array.any?}"
    puts "   - Image Switching: #{@application.property_images_array.length > 1 ? 'Enabled' : 'Not needed (single image)'}"
  end

  test "admin edit page works for applications without CoreLogic data" do
    # Create an application without CoreLogic data
    app_without_corelogic = applications(:second_application)
    app_without_corelogic.update!(
      corelogic_data: nil,
      property_images: nil,
      property_type: nil,
      property_id: nil
    )

    # Visit the admin application edit page
    get edit_admin_application_path(app_without_corelogic)
    assert_response :success
    assert_select "h2", text: "Application ##{app_without_corelogic.id}"

    # Verify property section is not displayed
    assert_select "h4", { text: "Property Information", count: 0 }

    puts "✅ Admin edit page works correctly for applications without property data!"
  end
end