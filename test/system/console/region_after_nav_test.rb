require "application_system_test_case"

class Console::RegionAfterNavTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_user)
    @admin.update!(password: "Region!Pick1", password_confirmation: "Region!Pick1")
  end

  test "region works after navigating via the Hotwire nav" do
    visit new_user_session_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "Region!Pick1"
    click_button "Sign In"
    assert_current_path console_root_path, wait: 5

    # Frame-navigate to Contracts (open the Operations group via JS first).
    execute_script("document.querySelectorAll('details.console-nav-group').forEach(d => d.open = true)")
    click_link "Contracts"
    assert_selector ".console-page-title", text: "Contracts", wait: 5
    page.assert_current_path console_contracts_path

    # Now click a region in the topbar.
    within ".console-region" do
      find("button.console-region-option", text: "AU").click
    end

    assert_selector "button.console-region-option.is-active", text: "AU", wait: 5
  end
end
