require "application_system_test_case"

class Admin::FunderPoolManagementSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def setup
    # Use actual production-like data setup
    @admin = User.create!(
      email: 'system_test_admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      verified: true,
      user_type: 'futureproof_admin'
    )
    
    @lender = Lender.create!(
      name: 'System Test Lender',
      lender_type: 'lender',
      country: 'Australia', 
      contact_email: 'system@test.com'
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: 'System Test Wholesale Funder',
      country: 'Australia',
      currency: 'AUD'
    )
    
    # Create relationship
    @lender.lender_wholesale_funders.create!(
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    # Create available pool
    @available_pool = @wholesale_funder.funder_pools.create!(
      name: 'Available Test Pool',
      amount: 5000000,
      allocated: 0,
      benchmark_rate: 4.0,
      margin_rate: 2.0
    )
    
    # Create existing pool relationship  
    @existing_pool = @wholesale_funder.funder_pools.create!(
      name: 'Existing Test Pool',
      amount: 10000000,
      allocated: 1000000,
      benchmark_rate: 3.5,
      margin_rate: 1.5
    )
    
    @existing_relationship = @lender.lender_funder_pools.create!(
      funder_pool: @existing_pool,
      active: true
    )
  end

  def teardown
    # Clean up test data
    User.where(email: 'system_test_admin@test.com').destroy_all
    Lender.where(name: 'System Test Lender').destroy_all
    WholesaleFunder.where(name: 'System Test Wholesale Funder').destroy_all
  end

  test "complete add funder pool workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO LENDER
    visit admin_lender_path(@lender)
    assert_text @lender.name
    
    # VERIFY EXISTING POOL IS SHOWN
    assert_text @existing_pool.name
    assert_text @existing_pool.formatted_amount
    
    # START ADD POOL WORKFLOW
    assert_text "Add Funder Pool"
    click_button "Add Funder Pool"
    
    # VERIFY SELECTION INTERFACE APPEARS
    assert_text "Available Funder Pools"
    assert_text @available_pool.name
    assert_text @available_pool.formatted_amount
    
    # ADD THE POOL
    within "[data-pool-id='#{@available_pool.id}']" do
      click_button "Add Pool"
    end
    
    # VERIFY POOL WAS ADDED (should appear in existing pools section)
    # Wait for Turbo Stream to update
    assert_text "#{@available_pool.name} added successfully", wait: 5
    
    # VERIFY POOL APPEARS IN POOLS LIST
    within "#existing-pools" do
      assert_text @available_pool.name
      assert_text @available_pool.formatted_amount
    end
    
    # VERIFY RELATIONSHIP WAS CREATED IN DATABASE
    assert @lender.lender_funder_pools.where(funder_pool: @available_pool).exists?
    
    puts "✅ ADD POOL WORKFLOW: PASSED"
  end

  test "complete remove funder pool workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email  
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO LENDER
    visit admin_lender_path(@lender)
    
    # VERIFY EXISTING POOL IS SHOWN
    assert_text @existing_pool.name
    
    # CLICK REMOVE BUTTON
    within ".pool-card" do
      # Accept the confirmation dialog
      accept_confirm do
        click_button "Remove"
      end
    end
    
    # VERIFY REMOVAL SUCCESS MESSAGE
    assert_text "successfully removed", wait: 5
    
    # VERIFY POOL NO LONGER APPEARS IN UI
    assert_no_text @existing_pool.name, wait: 5
    
    # VERIFY RELATIONSHIP WAS DELETED FROM DATABASE
    assert_not @lender.lender_funder_pools.where(funder_pool: @existing_pool).exists?
    
    puts "✅ REMOVE POOL WORKFLOW: PASSED"
  end

  test "toggle pool status workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO LENDER
    visit admin_lender_path(@lender)
    
    # CHECK INITIAL STATUS
    initial_status = @existing_relationship.active?
    status_text = initial_status ? "Active" : "Inactive"
    assert_text status_text
    
    # CLICK TOGGLE BUTTON
    within ".pool-card" do
      click_button "Toggle"
    end
    
    # WAIT FOR TURBO STREAM UPDATE
    sleep 1
    
    # VERIFY STATUS CHANGED IN DATABASE
    @existing_relationship.reload
    assert_not_equal initial_status, @existing_relationship.active?
    
    # VERIFY STATUS CHANGED IN UI
    new_status_text = @existing_relationship.active? ? "Active" : "Inactive"
    assert_text new_status_text
    
    puts "✅ TOGGLE POOL WORKFLOW: PASSED"
  end

  test "add remove re-add workflow (Stimulus preservation test)" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO LENDER
    visit admin_lender_path(@lender)
    
    # ADD POOL
    click_button "Add Funder Pool"
    within "[data-pool-id='#{@available_pool.id}']" do
      click_button "Add Pool"
    end
    
    # VERIFY POOL ADDED
    assert_text "#{@available_pool.name} added successfully", wait: 5
    assert @lender.lender_funder_pools.where(funder_pool: @available_pool).exists?
    
    # REMOVE POOL
    within ".pool-card" do
      if has_text?(@available_pool.name)
        accept_confirm do
          click_button "Remove"
        end
      end
    end
    
    # VERIFY POOL REMOVED
    assert_text "successfully removed", wait: 5
    assert_not @lender.lender_funder_pools.where(funder_pool: @available_pool).exists?
    
    # RE-ADD POOL (this is where the bug occurred)
    click_button "Add Funder Pool"
    
    # VERIFY INTERFACE STILL WORKS
    assert_text "Available Funder Pools", wait: 5
    assert_text @available_pool.name
    
    # ADD POOL AGAIN
    within "[data-pool-id='#{@available_pool.id}']" do
      click_button "Add Pool"
    end
    
    # VERIFY SECOND ADD WORKS
    assert_text "#{@available_pool.name} added successfully", wait: 5
    assert @lender.lender_funder_pools.where(funder_pool: @available_pool).exists?
    
    puts "✅ ADD/REMOVE/RE-ADD WORKFLOW: PASSED"
  end

  test "error handling when pools fail to load" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO LENDER
    visit admin_lender_path(@lender)
    
    # Remove all pools to test empty state
    @wholesale_funder.funder_pools.destroy_all
    
    # TRY TO ADD POOL
    click_button "Add Funder Pool"
    
    # SHOULD SHOW EMPTY STATE MESSAGE
    assert_text "No funder pools available", wait: 5
    
    puts "✅ ERROR HANDLING: PASSED"
  end
  
  private
  
  def take_screenshot_on_failure
    return unless ::Capybara::Screenshot.screenshot_and_save_page
    
    puts "Screenshot saved to: #{::Capybara::Screenshot.screenshot_and_save_page}"
  end
end