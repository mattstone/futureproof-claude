require "application_system_test_case"

class AdminLightboxSystemTest < ApplicationSystemTestCase
  def setup
    @admin = users(:admin_user)
    @application = Application.create!(
      user: users(:john),
      address: "123 Test Street",
      home_value: 500000,
      property_state: "primary_residence",
      ownership_status: "individual",
      borrower_age: 35,
      property_images: JSON.dump([
        "https://via.placeholder.com/400x300/FF0000/FFFFFF?text=Image+1",
        "https://via.placeholder.com/400x300/00FF00/FFFFFF?text=Image+2",
        "https://via.placeholder.com/400x300/0000FF/FFFFFF?text=Image+3"
      ])
    )
    sign_in @admin
  end

  test "admin can open, navigate, and close lightbox with property images" do
    visit admin_application_path(@application)

    # Verify property images are present
    assert_selector '.property-image', count: 3

    # Click on the first image to open lightbox
    first('.property-image').click

    # Verify lightbox opens and shows first image
    assert_selector '.image-lightbox:not(.hidden)', wait: 2
    assert_selector '.lightbox-image[src*="Image+1"]'
    assert_text "1 of 3"

    # Test next button
    find('.lightbox-next').click
    assert_selector '.lightbox-image[src*="Image+2"]', wait: 1
    assert_text "2 of 3"

    # Test next button again (should go to third image)
    find('.lightbox-next').click
    assert_selector '.lightbox-image[src*="Image+3"]', wait: 1
    assert_text "3 of 3"

    # Test next button again (should wrap to first image)
    find('.lightbox-next').click
    assert_selector '.lightbox-image[src*="Image+1"]', wait: 1
    assert_text "1 of 3"

    # Test previous button
    find('.lightbox-prev').click
    assert_selector '.lightbox-image[src*="Image+3"]', wait: 1
    assert_text "3 of 3"

    # Test close button
    find('.lightbox-close').click
    assert_selector '.image-lightbox.hidden', wait: 1

    # Test opening lightbox again and closing with overlay click
    first('.property-image').click
    assert_selector '.image-lightbox:not(.hidden)', wait: 2

    # Click overlay to close
    find('.lightbox-overlay').click
    assert_selector '.image-lightbox.hidden', wait: 1
  end

  test "keyboard navigation works in lightbox" do
    visit admin_application_path(@application)

    # Open lightbox
    first('.property-image').click
    assert_selector '.image-lightbox:not(.hidden)', wait: 2

    # Test right arrow key
    page.send_keys(:arrow_right)
    assert_selector '.lightbox-image[src*="Image+2"]', wait: 1
    assert_text "2 of 3"

    # Test left arrow key
    page.send_keys(:arrow_left)
    assert_selector '.lightbox-image[src*="Image+1"]', wait: 1
    assert_text "1 of 3"

    # Test escape key to close
    page.send_keys(:escape)
    assert_selector '.image-lightbox.hidden', wait: 1
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in'
    assert_current_path admin_root_path
  end
end