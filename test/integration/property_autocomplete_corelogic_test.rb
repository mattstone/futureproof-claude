require 'test_helper'

class PropertyAutocompleteCorelogicTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'Australia',
      terms_accepted: true
    )

    # Create application for the user
    @application = @user.applications.create!(
      status: 'created',
      ownership_status: 'individual',
      home_value: 1500000
    )
  end

  test "applications new page loads with property autocomplete functionality" do
    # Log in the user directly using sign_in helper (works in integration tests)
    sign_in @user

    # Visit the applications new page
    get '/applications/new'
    assert_response :success

    # Verify property autocomplete elements are present
    assert_select "div[data-controller*='property-autocomplete']", 1, "Should have property-autocomplete controller"
    assert_select "input[data-property-autocomplete-target='input']", 1, "Should have autocomplete input field"
    assert_select "div[data-property-autocomplete-target='suggestions']", 1, "Should have suggestions container"
    assert_select "div[data-property-autocomplete-target='propertyPreview']", 1, "Should have property preview container"

    # Verify hidden fields for CoreLogic data exist
    assert_select "input[data-field='property_type']", 1, "Should have property type hidden field"
    assert_select "input[data-field='property_images']", 1, "Should have property images hidden field"
    assert_select "input[data-field='corelogic_data']", 1, "Should have CoreLogic data hidden field"
    assert_select "input[data-field='property_valuation_low']", 1, "Should have valuation low hidden field"
    assert_select "input[data-field='property_valuation_middle']", 1, "Should have valuation middle hidden field"
    assert_select "input[data-field='property_valuation_high']", 1, "Should have valuation high hidden field"

    # Verify property preview section structure
    assert_select ".property-preview", 1, "Should have property preview section"
    assert_select ".property-preview-header", 1, "Should have property preview header"
    assert_select ".property-details-grid", 1, "Should have property details grid"
    assert_select ".property-valuation-notice", 1, "Should have valuation notice"

    # Verify home value slider is present
    assert_select "input[data-property-autocomplete-target='homeValue']", 1, "Should have home value slider target"
  end

  test "property preview section is hidden when no CoreLogic data" do
    # Log in the user
    sign_in @user

    get '/applications/new'
    assert_response :success

    # Property preview should be hidden by default (no CoreLogic data)
    assert_select ".property-preview[style*='display: none']", 1, "Property preview should be hidden when no data"
  end

  test "JavaScript controller targets are properly configured" do
    sign_in @user

    get '/applications/new'
    assert_response :success

    # Check all required Stimulus targets are present
    expected_targets = %w[input suggestions propertyPreview propertyId homeValue primaryImage]

    expected_targets.each do |target|
      assert_select "[data-property-autocomplete-target='#{target}'], [data-property-autocomplete-target*='#{target}']",
                    { minimum: 1 }, "Should have #{target} target"
    end
  end

  test "CSS classes for property preview styling are present" do
    sign_in @user

    get '/applications/new'
    assert_response :success

    # Verify key CSS classes for styling are present
    css_classes = [
      '.property-preview',
      '.property-preview-header',
      '.property-preview-content',
      '.property-details-grid',
      '.property-detail-item',
      '.property-images-gallery',
      '.autocomplete-container'
    ]

    css_classes.each do |css_class|
      selector = css_class.gsub('.', '')
      assert_select ".#{selector}", { minimum: 1 }, "Should have #{css_class} styling class"
    end
  end

  test "form has correct data attributes for property autocomplete" do
    sign_in @user

    get '/applications/new'
    assert_response :success

    # Verify form has correct data attributes
    assert_select "form[data-controller*='property-autocomplete']", 1
    assert_select "form[data-property-autocomplete-url-value]", 1, "Should have URL value for autocomplete"
    assert_select "form[data-property-autocomplete-min-chars-value='3']", 1, "Should have min chars value set to 3"
  end
end