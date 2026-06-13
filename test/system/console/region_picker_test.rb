require "application_system_test_case"

class Console::RegionPickerTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_user)
    @admin.update!(password: "Region!Pick1", password_confirmation: "Region!Pick1")
  end

  def sign_in_admin
    visit new_user_session_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "Region!Pick1"
    click_button "Sign In"
    assert_current_path console_root_path, wait: 5
  end

  test "selecting a region activates it" do
    sign_in_admin

    within ".console-region" do
      assert_selector ".console-region-option.is-active", text: "Summary"
      # Click the AU segment.
      find(".console-region-option", text: "AU").click
    end

    # After the submit + re-render, AU is the active segment.
    assert_selector ".console-region-option.is-active", text: "AU", wait: 5
    assert_no_selector ".console-region-option.is-active", text: "Summary"
  end
end
