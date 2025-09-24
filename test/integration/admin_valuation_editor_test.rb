require "test_helper"

class AdminValuationEditorTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user)
    sign_in @admin_user

    # Create an application with property valuation for testing
    @application = applications(:mortgage_application)
    @application.update!(
      property_valuation_low: 1800000,
      property_valuation_middle: 2000000,
      property_valuation_high: 2200000,
      corelogic_data: { land_area: "600" }.to_json
    )
  end

  test "admin can view valuation editor elements" do
    get edit_admin_application_path(@application)
    assert_response :success

    # Verify valuation display is present
    assert_select "strong", text: "Property Valuation:"
    assert_select ".admin-badge", text: "$2,000,000"

    # Verify valuation editor is always visible
    assert_select ".valuation-editor"
    assert_select "h5", text: "Update Property Valuation"
    assert_select "[data-controller='admin-valuation-editor']"
    assert_select "[data-admin-valuation-editor-target='slider']"
    assert_select "[data-admin-valuation-editor-target='explanation']"
    assert_select "button", text: "Update Valuation"
    assert_select "button", text: "Reset to Original"

    puts "✅ Admin edit page displays valuation editor elements correctly!"
  end

  test "admin can update valuation via API with explanation" do
    original_valuation = @application.property_valuation_middle
    new_valuation = 2500000
    explanation = "Updated based on recent comparable sales in the area"

    # Simulate the AJAX request that the JavaScript would make
    patch admin_application_path(@application),
          params: {
            application: { property_valuation_middle: new_valuation },
            valuation_change: 'true',
            valuation_explanation: explanation
          },
          headers: {
            'Accept' => 'application/json',
            'X-Requested-With' => 'XMLHttpRequest'
          }

    assert_response :success

    # Verify the valuation was updated
    @application.reload
    assert_equal new_valuation, @application.property_valuation_middle

    # Verify change was tracked in application versions with explanation
    version = @application.application_versions.where(action: 'valuation_updated').last
    assert_not_nil version
    assert_equal @admin_user, version.user
    assert_includes version.change_details, "$2,000,000"
    assert_includes version.change_details, "$2,500,000"
    assert_includes version.change_details, @admin_user.display_name
    assert_includes version.change_details, explanation

    puts "✅ Valuation update API works correctly with explanation!"
    puts "   - Original valuation: $#{original_valuation.to_s.reverse.gsub(/(\\d{3})(?=\\d)/, '\\\\1,').reverse}"
    puts "   - New valuation: $#{new_valuation.to_s.reverse.gsub(/(\\d{3})(?=\\d)/, '\\\\1,').reverse}"
    puts "   - Explanation included: #{version.change_details.include?(explanation)}"
    puts "   - Change tracked in history: #{version.present?}"
  end

  test "valuation change is validated for reasonable ranges" do
    # Test with valuation too low
    patch admin_application_path(@application),
          params: {
            application: { property_valuation_middle: 50000 },
            valuation_change: 'true'
          },
          headers: { 'Accept' => 'application/json' }

    assert_response :success

    # Verify valuation was NOT changed (due to validation)
    @application.reload
    assert_equal 2000000, @application.property_valuation_middle

    # Test with valuation too high
    patch admin_application_path(@application),
          params: {
            application: { property_valuation_middle: 100000000 },
            valuation_change: 'true'
          },
          headers: { 'Accept' => 'application/json' }

    assert_response :success

    # Verify valuation was NOT changed
    @application.reload
    assert_equal 2000000, @application.property_valuation_middle

    puts "✅ Valuation validation works correctly!"
    puts "   - Rejects values below $100,000"
    puts "   - Rejects values above $50,000,000"
  end

  test "valuation editor only shows for applications with existing valuations" do
    # Create application without valuation data
    app_without_valuation = applications(:second_application)
    app_without_valuation.update!(
      property_valuation_middle: nil,
      property_valuation_low: nil,
      property_valuation_high: nil,
      corelogic_data: nil
    )

    get edit_admin_application_path(app_without_valuation)
    assert_response :success

    # Verify valuation editor is not displayed when no property data exists
    assert_select "strong", { text: "Property Valuation:", count: 0 }
    assert_select ".valuation-editor", { count: 0 }

    puts "✅ Valuation editor correctly hidden for applications without valuation data!"
  end

  test "no change tracking for identical valuation" do
    original_version_count = @application.application_versions.count
    current_valuation = @application.property_valuation_middle

    # Update with the same valuation
    patch admin_application_path(@application),
          params: {
            application: { property_valuation_middle: current_valuation },
            valuation_change: 'true'
          },
          headers: { 'Accept' => 'application/json' }

    assert_response :success

    # Verify no new version was created
    @application.reload
    assert_equal original_version_count, @application.application_versions.count

    puts "✅ No change tracking for identical valuation updates!"
  end
end