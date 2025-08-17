require "application_system_test_case"

class Admin::MortgageLenderManagementSystemTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def setup
    # Use actual production-like data setup
    @admin = User.create!(
      email: 'mortgage_admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      verified: true,
      user_type: 'futureproof_admin'
    )
    
    @mortgage = Mortgage.create!(
      name: 'System Test Mortgage',
      mortgage_type: 'interest_only',
      lvr: 80.0
    )
    
    @lender_1 = Lender.create!(
      name: 'System Test Lender 1',
      lender_type: 'lender',
      country: 'Australia', 
      contact_email: 'lender1@test.com'
    )
    
    @lender_2 = Lender.create!(
      name: 'System Test Lender 2',
      lender_type: 'lender',
      country: 'Australia', 
      contact_email: 'lender2@test.com'
    )
    
    # Create an existing relationship
    @existing_relationship = @mortgage.mortgage_lenders.create!(
      lender: @lender_1,
      active: true
    )
  end

  def teardown
    # Clean up test data
    User.where(email: 'mortgage_admin@test.com').destroy_all
    Mortgage.where(name: 'System Test Mortgage').destroy_all
    Lender.where(name: ['System Test Lender 1', 'System Test Lender 2']).destroy_all
  end

  test "complete add lender workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO MORTGAGE
    visit admin_mortgage_path(@mortgage)
    assert_text @mortgage.name
    
    # VERIFY EXISTING LENDER IS SHOWN
    assert_text @lender_1.name
    assert_text @lender_1.contact_email
    
    # START ADD LENDER WORKFLOW
    assert_text "Add Lender"
    click_button "Add Lender"
    
    # VERIFY SELECTION INTERFACE APPEARS
    assert_text "Available Lenders"
    assert_text @lender_2.name
    assert_text @lender_2.contact_email
    
    # ADD THE LENDER
    within "[data-lender-id='#{@lender_2.id}']" do
      click_button "Add Lender"
    end
    
    # VERIFY LENDER WAS ADDED (should appear in existing lenders section)
    # Wait for Turbo Stream to update
    assert_text "#{@lender_2.name} added to mortgage successfully", wait: 5
    
    # VERIFY LENDER APPEARS IN LENDERS LIST
    within "#existing-lenders" do
      assert_text @lender_2.name
      assert_text @lender_2.contact_email
    end
    
    # VERIFY RELATIONSHIP WAS CREATED IN DATABASE
    assert @mortgage.mortgage_lenders.where(lender: @lender_2).exists?
    
    puts "✅ ADD LENDER WORKFLOW: PASSED"
  end

  test "complete remove lender workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email  
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO MORTGAGE
    visit admin_mortgage_path(@mortgage)
    
    # VERIFY EXISTING LENDER IS SHOWN
    assert_text @lender_1.name
    
    # CLICK REMOVE BUTTON
    within ".lender-card" do
      # Accept the confirmation dialog
      accept_confirm do
        click_button "Remove"
      end
    end
    
    # VERIFY REMOVAL SUCCESS MESSAGE
    assert_text "successfully removed", wait: 5
    
    # VERIFY LENDER NO LONGER APPEARS IN UI
    assert_no_text @lender_1.name, wait: 5
    
    # VERIFY RELATIONSHIP WAS DELETED FROM DATABASE
    assert_not @mortgage.mortgage_lenders.where(lender: @lender_1).exists?
    
    puts "✅ REMOVE LENDER WORKFLOW: PASSED"
  end

  test "toggle lender status workflow" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO MORTGAGE
    visit admin_mortgage_path(@mortgage)
    
    # CHECK INITIAL STATUS
    initial_status = @existing_relationship.active?
    status_text = initial_status ? "Active" : "Inactive"
    assert_text status_text
    
    # CLICK TOGGLE BUTTON
    within ".lender-card" do
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
    
    puts "✅ TOGGLE LENDER WORKFLOW: PASSED"
  end

  test "add remove re-add workflow (Stimulus preservation test)" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO MORTGAGE
    visit admin_mortgage_path(@mortgage)
    
    # ADD LENDER
    click_button "Add Lender"
    within "[data-lender-id='#{@lender_2.id}']" do
      click_button "Add Lender"
    end
    
    # VERIFY LENDER ADDED
    assert_text "#{@lender_2.name} added to mortgage successfully", wait: 5
    assert @mortgage.mortgage_lenders.where(lender: @lender_2).exists?
    
    # REMOVE LENDER
    within ".lender-card" do
      if has_text?(@lender_2.name)
        accept_confirm do
          click_button "Remove"
        end
      end
    end
    
    # VERIFY LENDER REMOVED
    assert_text "successfully removed", wait: 5
    assert_not @mortgage.mortgage_lenders.where(lender: @lender_2).exists?
    
    # RE-ADD LENDER (this is where the bug occurred)
    click_button "Add Lender"
    
    # VERIFY INTERFACE STILL WORKS
    assert_text "Available Lenders", wait: 5
    assert_text @lender_2.name
    
    # ADD LENDER AGAIN
    within "[data-lender-id='#{@lender_2.id}']" do
      click_button "Add Lender"
    end
    
    # VERIFY SECOND ADD WORKS
    assert_text "#{@lender_2.name} added to mortgage successfully", wait: 5
    assert @mortgage.mortgage_lenders.where(lender: @lender_2).exists?
    
    puts "✅ ADD/REMOVE/RE-ADD WORKFLOW: PASSED"
  end

  test "error handling when lenders fail to load" do
    # LOGIN
    visit root_path
    fill_in 'Email', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign in'
    
    # NAVIGATE TO MORTGAGE
    visit admin_mortgage_path(@mortgage)
    
    # Add all lenders to test empty state
    @mortgage.mortgage_lenders.create!(lender: @lender_2, active: true)
    
    # TRY TO ADD LENDER
    click_button "Add Lender"
    
    # SHOULD SHOW EMPTY STATE MESSAGE
    assert_text "No lenders available", wait: 5
    
    puts "✅ ERROR HANDLING: PASSED"
  end
  
  private
  
  def take_screenshot_on_failure
    return unless ::Capybara::Screenshot.screenshot_and_save_page
    
    puts "Screenshot saved to: #{::Capybara::Screenshot.screenshot_and_save_page}"
  end
end