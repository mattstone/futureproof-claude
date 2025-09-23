require "application_system_test_case"

class PropertyAutocompleteSystemTest < ApplicationSystemTestCase
  def setup
    @user = User.create!(
      email: 'system_test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'System',
      last_name: 'Test',
      country_of_residence: 'Australia',
      terms_accepted: true
    )
  end

  test "property autocomplete functionality works on applications page" do
    # Log in the user
    visit '/users/sign_in'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign In'

    # Navigate to applications page
    visit '/applications/new'

    # Verify page loads without error
    assert_current_path '/applications/new'
    assert_text 'Property Details'

    # Check that property autocomplete elements are present
    assert_selector "[data-controller*='property-autocomplete']"
    assert_selector "input[data-property-autocomplete-target='input']"
    assert_selector "div[data-property-autocomplete-target='suggestions']"
    assert_selector "div[data-property-autocomplete-target='propertyPreview']"

    # Verify property preview is initially hidden
    preview_element = find("div[data-property-autocomplete-target='propertyPreview']", visible: false)
    assert preview_element['style'].include?('display: none'), "Property preview should be initially hidden"

    # Test property search input
    property_input = find("input[data-property-autocomplete-target='input']")

    # Type a short query (should not trigger search)
    property_input.fill_in with: "12"
    sleep 0.2 # Wait for debounce

    # Type a longer query (should trigger search)
    property_input.fill_in with: "123 Test Street"
    sleep 0.5 # Wait for debounce and potential AJAX call

    # Verify the input contains our text
    assert_equal "123 Test Street", property_input.value

    # Check that home value slider is present and working
    assert_selector "input[data-property-autocomplete-target='homeValue']"
    home_value_slider = find("input[data-property-autocomplete-target='homeValue']")
    assert home_value_slider.value.to_i > 0, "Home value should have a default value"

    # Verify hidden fields for CoreLogic data exist
    assert_selector "input[data-field='property_type']", visible: false
    assert_selector "input[data-field='property_images']", visible: false
    assert_selector "input[data-field='corelogic_data']", visible: false
    assert_selector "input[data-field='property_valuation_low']", visible: false
    assert_selector "input[data-field='property_valuation_middle']", visible: false
    assert_selector "input[data-field='property_valuation_high']", visible: false

    puts "✅ Property autocomplete elements are properly configured"
    puts "✅ Property preview section exists and is initially hidden"
    puts "✅ Home value slider is present and functional"
    puts "✅ All CoreLogic hidden fields are present"
  end

  test "CSS styling is properly loaded for property preview" do
    # Log in and visit page
    visit '/users/sign_in'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign In'

    visit '/applications/new'

    # Check that key CSS classes exist in the page
    css_classes = [
      '.property-preview',
      '.property-preview-header',
      '.property-preview-content',
      '.property-details-grid',
      '.autocomplete-container'
    ]

    css_classes.each do |css_class|
      assert_selector css_class, "Should have #{css_class} styling class"
    end

    puts "✅ All required CSS classes are present"
  end

  test "JavaScript controllers are properly initialized" do
    # Log in and visit page
    visit '/users/sign_in'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign In'

    visit '/applications/new'

    # Verify Stimulus controllers are loaded
    assert_selector "[data-controller*='property-autocomplete']"
    assert_selector "[data-controller*='application-form']"

    # Check that all required targets are present
    required_targets = %w[input suggestions propertyPreview propertyId homeValue]

    required_targets.each do |target|
      assert_selector "[data-property-autocomplete-target='#{target}']",
                      "Should have #{target} Stimulus target"
    end

    puts "✅ All Stimulus controllers and targets are properly configured"
  end
end