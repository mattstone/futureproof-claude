require 'application_system_test_case'

class Admin::ApplicationChecklistSystemTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(
      first_name: "Admin",
      last_name: "Test",
      email: "admin-checklist@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @regular_user = User.create!(
      first_name: "John",
      last_name: "Doe",
      email: "user-checklist@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    # Create processing application with checklist
    @processing_application = Application.create!(
      user: @regular_user,
      address: "123 Processing Street, Portland, OR",
      home_value: 800000,
      status: 'processing',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )

    # Create checklist items for processing application
    @checklist_items = ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.map.with_index do |item_name, index|
      ApplicationChecklist.create!(
        application: @processing_application,
        name: item_name,
        position: index,
        completed: false
      )
    end

    # Create submitted application (should auto-create checklist)
    @submitted_application = Application.create!(
      user: @regular_user,
      address: "456 Submitted Avenue, Seattle, WA",
      home_value: 600000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 67
    )

    @ai_agent = AiAgent.find_or_create_by(name: 'TestAgent') do |agent|
      agent.agent_type = 'applications'
      agent.is_active = true
      agent.greeting_style = 'friendly'
    end
  end

  test "admin can view checklist on processing application show page" do
    sign_in_admin
    visit admin_application_path(@processing_application)

    # Should show processing checklist
    assert page.has_text?("Processing Checklist")
    assert page.has_text?("Complete all items below to approve the application")

    # Should show progress bar at 0%
    assert page.has_text?("0 of 4 completed")
    assert page.has_text?("(0%)")

    # Should show all checklist items as unchecked (read-only)
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each do |item_name|
      assert page.has_text?(item_name)
      # Find the checkbox for this item and verify it's unchecked and disabled
      checkbox = page.find("input[type='checkbox']", text: item_name, visible: false)
      assert_not checkbox.checked?
      assert checkbox.disabled?
    end

    # Should not show completion message
    assert_not page.has_text?("All checklist items completed!")
  end

  test "admin can edit checklist items on processing application edit page" do
    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show editable checklist
    assert page.has_text?("Processing Checklist")
    assert page.has_text?("Complete all items below to approve the application")

    # Should show progress at 0%
    assert page.has_text?("0 of 4 completed")
    assert page.has_text?("(0%)")

    # Check the first item
    first_item = @checklist_items.first
    checkbox_selector = "input[type='checkbox'][value='true']"
    first_checkbox = page.all(checkbox_selector).first

    assert_not first_checkbox.checked?
    first_checkbox.check

    # Wait for Turbo Stream update
    sleep 0.5

    # Progress should update to 25%
    assert page.has_text?("1 of 4 completed")
    assert page.has_text?("(25%)")

    # Check the second item
    second_checkbox = page.all(checkbox_selector)[1]
    second_checkbox.check
    sleep 0.5

    # Progress should update to 50%
    assert page.has_text?("2 of 4 completed")
    assert page.has_text?("(50%)")

    # Check the third item
    third_checkbox = page.all(checkbox_selector)[2]
    third_checkbox.check
    sleep 0.5

    # Progress should update to 75%
    assert page.has_text?("3 of 4 completed")
    assert page.has_text?("(75%)")

    # Check the fourth (last) item
    fourth_checkbox = page.all(checkbox_selector)[3]
    fourth_checkbox.check
    sleep 0.5

    # Progress should update to 100%
    assert page.has_text?("4 of 4 completed")
    assert page.has_text?("(100%)")

    # Should show completion message
    assert page.has_text?("All checklist items completed!")
    assert page.has_text?("This application is ready for manual approval")

    # Status dropdown should now include "Accepted" option
    within('.status-update-section') do
      assert page.has_select?('application[status]', with_options: ['Processing', 'Rejected', 'Accepted'])
      assert page.has_text?("All checklist items completed. Application can be accepted, rejected, or kept in processing.")
    end
  end

  test "admin can manually approve application after checklist completion" do
    # Complete all checklist items first
    @checklist_items.each { |item| item.mark_completed!(@admin) }

    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show completion message and status options
    assert page.has_text?("All checklist items completed!")
    assert page.has_text?("This application is ready for manual approval")

    # Change status to accepted
    within('.status-update-section') do
      select 'Accepted', from: 'application[status]'
      click_button 'Update Status'
    end

    # Should redirect to show page
    assert_current_path admin_application_path(@processing_application)

    # Should show success message
    assert page.has_text?("Application was successfully updated")

    # Application status should be accepted
    within('.application-status') do
      assert page.has_text?("Accepted")
    end

    # Should show accepted checklist view
    assert page.has_text?("Application approved - all checklist items completed")
    assert page.has_text?("4 of 4 completed (100%)")
    assert page.has_text?("Application Approved!")
  end

  test "admin cannot approve application with incomplete checklist" do
    # Only complete 2 out of 4 items
    @checklist_items[0].mark_completed!(@admin)
    @checklist_items[1].mark_completed!(@admin)

    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show 50% completion
    assert page.has_text?("2 of 4 completed")
    assert page.has_text?("(50%)")

    # Should not show "Accepted" option
    within('.status-update-section') do
      assert_not page.has_select?('application[status]', with_options: ['Accepted'])
      assert page.has_select?('application[status]', with_options: ['Processing', 'Rejected'])
      assert page.has_text?("Complete all checklist items to enable \"Accepted\" status")
    end
  end

  test "checklist change history is recorded for each interaction" do
    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Check the first item
    first_checkbox = page.all("input[type='checkbox'][value='true']").first
    first_checkbox.check
    sleep 0.5

    # Navigate to show page to check change history
    visit admin_application_path(@processing_application)

    # Should show change history entry for checklist update
    within('.change-history-section') do
      assert page.has_text?("checklist_updated")
      assert page.has_text?("Checklist item 'Verification of identity check' marked as completed by #{@admin.display_name}")
    end
  end

  test "submitted application shows advance to processing button" do
    sign_in_admin
    visit admin_application_path(@submitted_application)

    # Should show submitted application interface
    assert page.has_text?("Application Submitted")
    assert page.has_text?("This application is ready to be processed")
    assert page.has_button?("Start Processing")

    # Click start processing button
    click_button "Start Processing"

    # Should redirect back to show page
    assert_current_path admin_application_path(@submitted_application)

    # Should show success message
    assert page.has_text?("Application advanced to processing and checklist created")

    # Should now show processing checklist
    assert page.has_text?("Processing Checklist")
    assert page.has_text?("0 of 4 completed")

    # Application status should be processing
    within('.application-status') do
      assert page.has_text?("Processing")
    end
  end

  test "auto-created checklist contains standard items" do
    # Trigger auto-creation by changing submitted application to processing
    @submitted_application.current_user = @admin
    @submitted_application.update!(status: 'processing')

    sign_in_admin
    visit admin_application_path(@submitted_application)

    # Should show all standard checklist items
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each do |item_name|
      assert page.has_text?(item_name)
    end

    # Should show correct progress
    assert page.has_text?("0 of 4 completed")
    assert page.has_text?("(0%)")
  end

  test "progress bar visual updates work correctly" do
    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show 0% progress bar width initially
    progress_fill = page.find('.progress-fill')
    assert progress_fill.has_css?('.progress-0')

    # Check first item
    first_checkbox = page.all("input[type='checkbox'][value='true']").first
    first_checkbox.check
    sleep 0.5

    # Progress bar should update to 25%
    progress_fill = page.find('.progress-fill')
    assert progress_fill.has_css?('.progress-25')

    # Check second item
    second_checkbox = page.all("input[type='checkbox'][value='true']")[1]
    second_checkbox.check
    sleep 0.5

    # Progress bar should update to 50%
    progress_fill = page.find('.progress-fill')
    assert progress_fill.has_css?('.progress-50')
  end

  test "unchecking items updates progress correctly" do
    # Pre-complete all items
    @checklist_items.each { |item| item.mark_completed!(@admin) }

    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show 100% completion
    assert page.has_text?("4 of 4 completed")
    assert page.has_text?("(100%)")

    # Uncheck one item
    first_checkbox = page.all("input[type='checkbox'][value='true']").first
    first_checkbox.uncheck
    sleep 0.5

    # Progress should decrease to 75%
    assert page.has_text?("3 of 4 completed")
    assert page.has_text?("(75%)")

    # Should not show completion message anymore
    assert_not page.has_text?("All checklist items completed!")

    # Status dropdown should not include "Accepted" option anymore
    within('.status-update-section') do
      assert_not page.has_select?('application[status]', with_options: ['Accepted'])
      assert page.has_text?("Complete all checklist items to enable \"Accepted\" status")
    end
  end

  test "checklist functionality works without JavaScript (fallback)" do
    # Disable JavaScript for this test
    Capybara.current_driver = :selenium_chrome_headless_no_js

    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Check first item (without JS, will do full page reload)
    first_checkbox = page.all("input[type='checkbox'][value='true']").first
    first_checkbox.check

    # Find and submit the form manually (since no JS auto-submission)
    form = first_checkbox.find(:xpath, './ancestor::form')
    within(form) do
      click_button 'Update'
    end

    # Should redirect back to edit page
    assert_current_path edit_admin_application_path(@processing_application)

    # Progress should update
    assert page.has_text?("1 of 4 completed")
    assert page.has_text?("(25%)")

    # Reset driver
    Capybara.current_driver = Capybara.default_driver
  end

  test "multiple admins can work on same checklist concurrently" do
    # Create second admin
    second_admin = User.create!(
      first_name: "Second",
      last_name: "Admin",
      email: "admin2-checklist@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    # First admin completes first item
    @checklist_items.first.mark_completed!(@admin)

    sign_in_admin
    visit edit_admin_application_path(@processing_application)

    # Should show first item completed by original admin
    assert page.has_text?("1 of 4 completed")
    assert page.has_text?("Completed by #{@admin.display_name}")

    # Check second item as first admin
    second_checkbox = page.all("input[type='checkbox'][value='true']")[1]
    second_checkbox.check
    sleep 0.5

    # Should show 50% completion
    assert page.has_text?("2 of 4 completed")

    # Simulate second admin checking third item in database
    @checklist_items[2].mark_completed!(second_admin)

    # Refresh page to see second admin's changes
    visit edit_admin_application_path(@processing_application)

    # Should show 75% completion with both admins' work
    assert page.has_text?("3 of 4 completed")
    assert page.has_text?("(75%)")
  end

  test "server-side validation prevents accepting incomplete checklist" do
    # Only complete 2 out of 4 items
    @checklist_items[0].mark_completed!(@admin)
    @checklist_items[1].mark_completed!(@admin)

    # Try to manually set status to accepted via direct update (bypassing UI)
    @processing_application.current_user = @admin
    assert_not @processing_application.update(status: 'accepted')

    # Should have validation error
    assert @processing_application.errors[:status].present?
    assert @processing_application.errors[:status].include?("cannot be set to accepted until all checklist items are completed")
  end

  private

  def sign_in_admin
    visit new_user_session_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "password123"
    click_button "Sign In"

    # Wait for successful sign in
    assert page.has_text?("Dashboard")
  end

  # Configure Chrome without JavaScript for fallback testing
  def self.setup_chrome_no_js
    Capybara.register_driver :selenium_chrome_headless_no_js do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument('--disable-javascript')
      options.add_argument('--window-size=1400,1400')

      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end
  end
end