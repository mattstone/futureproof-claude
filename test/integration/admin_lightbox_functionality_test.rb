require 'test_helper'

class AdminLightboxFunctionalityTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    @application = Application.create!(
      user: users(:john),
      address: "123 Test Street",
      home_value: 500000,
      property_state: "primary_residence",
      ownership_status: "individual",
      borrower_age: 35,
      property_images: JSON.dump(["https://example.com/image1.jpg", "https://example.com/image2.jpg"])
    )
    sign_in @admin
  end

  test "admin can view application with property images and lightbox controller is loaded" do
    get admin_application_path(@application)
    assert_response :success

    # Verify that property images section is present
    assert_select '.property-images-grid'
    assert_select 'img.property-image', count: 2

    # Verify that the image-lightbox controller is attached to the container
    assert_select '[data-controller="image-lightbox"]'

    # Verify that images have the correct data-action for showing lightbox
    assert_select 'img[data-action="click->image-lightbox#show"]', count: 2

    # Verify that images have correct src attributes
    assert_select 'img[src="https://example.com/image1.jpg"]'
    assert_select 'img[src="https://example.com/image2.jpg"]'
  end

  test "property images have proper structure for lightbox" do
    get admin_application_path(@application)
    assert_response :success

    # Check that the property images grid container exists
    assert_select '.property-images-grid' do
      # Each image should be in a property-image-item container
      assert_select '.property-image-item', count: 2

      # Each image should have the proper classes and attributes
      assert_select 'img.property-image' do |images|
        images.each_with_index do |img, index|
          assert img['loading'] == 'lazy'
          assert img['data-action'] == 'click->image-lightbox#show'
          assert img['alt'] == "Property image #{index + 1}"
        end
      end
    end
  end

  test "page includes image lightbox controller javascript" do
    get admin_application_path(@application)
    assert_response :success

    # The response should include references to the stimulus controller
    # This verifies the controller file will be loaded by the asset pipeline
    response_body = response.body

    # Check for Stimulus data attributes that indicate the controller will be loaded
    assert_match(/data-controller="image-lightbox"/, response_body)
    assert_match(/data-action="click->image-lightbox#show"/, response_body)
  end

  test "application without property images does not show lightbox section" do
    @application.update!(property_images: nil)

    get admin_application_path(@application)
    assert_response :success

    # Should not have property images section
    assert_select '.property-images-grid', count: 0
    assert_select '[data-controller="image-lightbox"]', count: 0
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: 'password' } }
  end
end