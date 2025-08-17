require "application_system_test_case"

class Admin::WholesaleFunderWorkflowTest < ApplicationSystemTestCase
  setup do
    @admin_user = users(:admin_user)
    @lender = lenders(:futureproof)
    @wholesale_funder = wholesale_funders(:alpha_funding)
    
    sign_in @admin_user
  end

  test "complete workflow: navigate to lender, add wholesale funder, add pool" do
    # Step 1: Navigate to lenders page from navigation menu
    visit admin_lenders_path
    assert_text "Lenders"
    
    # Step 2: Select the first lender
    within first(".admin-table tbody tr") do
      click_link @lender.name
    end
    
    assert_current_path admin_lender_path(@lender)
    assert_text @lender.name
    
    # Step 3: Click "Add Wholesale Funder" button 
    within ".admin-card[data-controller='wholesale-funder-selector']" do
      click_button "Add Wholesale Funder"
    end
    
    # Step 4: Verify the selection interface appears
    assert_selector "[data-wholesale-funder-selector-target='selectionInterface']", visible: true
    assert_text "Available Wholesale Funders"
    
    # Step 5: Wait for wholesale funders to load and select one
    assert_text "Loading available wholesale funders", wait: 2
    
    # Wait for the actual wholesale funders to appear
    within "[data-wholesale-funder-selector-target='availableFundersContainer']", wait: 5 do
      assert_text @wholesale_funder.name
      click_button "Select"
    end
    
    # Step 6: Verify the wholesale funder was added
    within "[data-wholesale-funder-selector-target='existingRelationships']" do
      assert_text @wholesale_funder.name
      assert_text "Active"
    end
    
    # Step 7: Verify the selection interface is hidden
    assert_selector "[data-wholesale-funder-selector-target='selectionInterface']", visible: false
    
    # Step 8: Add a funder pool (if available)
    if @wholesale_funder.funder_pools.any?
      click_link "Add Funder Pool"
      
      # Select a pool and add it
      if page.has_select?("lender_funder_pool[funder_pool_id]")
        select @wholesale_funder.funder_pools.first.name, from: "lender_funder_pool[funder_pool_id]"
        click_button "Add Funder Pool"
        
        # Verify the pool was added
        assert_text @wholesale_funder.funder_pools.first.name
      end
    end
    
    # Step 9: Test Remove functionality
    within "[data-wholesale-funder-selector-target='existingRelationships']" do
      within ".relationship-card", text: @wholesale_funder.name do
        accept_confirm do
          click_button "Remove"
        end
      end
    end
    
    # Step 10: Verify the wholesale funder was removed
    assert_no_text @wholesale_funder.name, wait: 3
  end

  test "add wholesale funder button works after page refresh" do
    # This tests the specific bug reported by the user
    
    # Step 1: Navigate to lender page
    visit admin_lender_path(@lender)
    
    # Step 2: Try clicking Add Wholesale Funder (this should work)
    within ".admin-card[data-controller='wholesale-funder-selector']" do
      click_button "Add Wholesale Funder"
    end
    
    # Step 3: Verify it works
    assert_selector "[data-wholesale-funder-selector-target='selectionInterface']", visible: true
    
    # Step 4: Close the interface
    within "[data-wholesale-funder-selector-target='selectionInterface']" do
      click_button "×"
    end
    
    # Step 5: Refresh the page
    page.refresh
    
    # Step 6: Try again (this should also work now)
    within ".admin-card[data-controller='wholesale-funder-selector']" do
      click_button "Add Wholesale Funder"
    end
    
    # Step 7: Verify it still works after refresh
    assert_selector "[data-wholesale-funder-selector-target='selectionInterface']", visible: true
  end

  test "no CSP violations in console" do
    # Navigate through the workflow and check for CSP errors
    visit admin_lender_path(@lender)
    
    # Click the Add Wholesale Funder button
    within ".admin-card[data-controller='wholesale-funder-selector']" do
      click_button "Add Wholesale Funder"
    end
    
    # Check console for errors (this is a basic check, full CSP testing requires browser dev tools)
    logs = page.driver.browser.logs.get(:browser)
    csp_errors = logs.select { |log| log.message.include?("Content Security Policy") }
    
    assert_empty csp_errors, "Found CSP violations: #{csp_errors.map(&:message).join(', ')}"
  end
end