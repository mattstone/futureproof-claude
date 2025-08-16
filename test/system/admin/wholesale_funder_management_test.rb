require "application_system_test_case"

class Admin::WholesaleFunderManagementTest < ApplicationSystemTestCase
  setup do
    @lender = lenders(:one)
    @wholesale_funder = wholesale_funders(:one)
    @funder_pool = funder_pools(:one)
    @admin_user = users(:admin)
    
    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Sign in"
  end

  test "pool toggle button should use turbo stream and not refresh page" do
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    # Verify the page loaded correctly
    assert_text "Select Wholesale Funders & Manage Pools"
    
    # Find a pool toggle button (should be inactive initially)
    pool_button = find("#pool-toggle-#{@funder_pool.id}")
    assert pool_button.has_text?("Inactive")
    assert pool_button[:class].include?("inactive")
    
    # Click the button and verify Turbo Stream response
    pool_button.click
    
    # Wait for the Turbo Stream to update the DOM
    assert_no_text "Loading...", wait: 1
    
    # Verify the button updated without page refresh
    updated_button = find("#pool-toggle-#{@funder_pool.id}")
    assert updated_button.has_text?("Active")
    assert updated_button[:class].include?("active")
    
    # Verify flash message appeared
    assert_text "#{@funder_pool.name} activated"
    
    # Click again to toggle back
    updated_button.click
    
    # Verify it toggles back to inactive
    final_button = find("#pool-toggle-#{@funder_pool.id}")
    assert final_button.has_text?("Inactive")
    assert final_button[:class].include?("inactive")
    
    # Verify flash message for deactivation
    assert_text "#{@funder_pool.name} deactivated"
  end

  test "multiple pool toggles should work independently" do
    # Create additional funder pool for testing
    another_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Test Pool 2",
      amount: 1000000,
      allocated: 0,
      total_rate: 5.5
    )
    
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    # Toggle first pool
    first_button = find("#pool-toggle-#{@funder_pool.id}")
    first_button.click
    
    # Wait and verify first pool is active
    assert find("#pool-toggle-#{@funder_pool.id}").has_text?("Active")
    
    # Toggle second pool
    second_button = find("#pool-toggle-#{another_pool.id}")
    second_button.click
    
    # Verify both pools can be active independently
    assert find("#pool-toggle-#{@funder_pool.id}").has_text?("Active")
    assert find("#pool-toggle-#{another_pool.id}").has_text?("Active")
    
    # Toggle first pool off
    find("#pool-toggle-#{@funder_pool.id}").click
    
    # Verify first is inactive but second remains active
    assert find("#pool-toggle-#{@funder_pool.id}").has_text?("Inactive")
    assert find("#pool-toggle-#{another_pool.id}").has_text?("Active")
  end

  test "page should not refresh during pool toggles" do
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    # Add a unique element to verify page doesn't refresh
    page.execute_script("document.body.setAttribute('data-test-marker', 'page-loaded')")
    
    # Toggle pool
    find("#pool-toggle-#{@funder_pool.id}").click
    
    # Wait for response
    sleep 0.5
    
    # Verify our test marker is still there (page didn't refresh)
    marker = page.evaluate_script("document.body.getAttribute('data-test-marker')")
    assert_equal "page-loaded", marker
  end

  test "flash messages should auto-hide after timeout" do
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    # Toggle pool to trigger flash message
    find("#pool-toggle-#{@funder_pool.id}").click
    
    # Verify flash message appears
    flash_message = find(".alert-success")
    assert_text "#{@funder_pool.name} activated"
    
    # Wait for auto-hide (3 seconds + buffer)
    sleep 4
    
    # Verify flash message is hidden
    assert_not flash_message.visible?
  end

  test "turbo stream should handle errors gracefully" do
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    # Simulate error by modifying the pool ID to invalid value
    page.execute_script(
      "document.querySelector('#pool-toggle-#{@funder_pool.id}').closest('form').action = " \
      "document.querySelector('#pool-toggle-#{@funder_pool.id}').closest('form').action.replace('#{@funder_pool.id}', '999999')"
    )
    
    # Click the modified button
    find("#pool-toggle-#{@funder_pool.id}").click
    
    # Should handle error gracefully (no page crash)
    # Note: This might show an error message or just not update
    sleep 1
    
    # Page should still be functional
    assert_text "Select Wholesale Funders & Manage Pools"
  end

  test "button styling should update correctly via turbo stream" do
    visit new_admin_lender_wholesale_funder_path(@lender)
    
    button = find("#pool-toggle-#{@funder_pool.id}")
    
    # Check initial styling (inactive)
    initial_classes = button[:class]
    assert initial_classes.include?("inactive")
    assert_not initial_classes.include?("active")
    
    # Click to activate
    button.click
    
    # Check updated styling (active)
    updated_button = find("#pool-toggle-#{@funder_pool.id}")
    updated_classes = updated_button[:class]
    assert updated_classes.include?("active")
    assert_not updated_classes.include?("inactive")
  end
end