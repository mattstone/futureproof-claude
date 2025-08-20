require 'test_helper'

class Admin::ApplicationChecklistWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Admin",
      last_name: "Test",
      email: "admin-workflow@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @regular_user = User.create!(
      first_name: "John", 
      last_name: "Doe",
      email: "user-workflow@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @submitted_application = Application.create!(
      user: @regular_user,
      address: "123 Workflow Street, Portland, OR",
      home_value: 800000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )

    @processing_application = Application.create!(
      user: @regular_user,
      address: "456 Processing Ave, Seattle, WA", 
      home_value: 600000,
      status: 'processing',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 67
    )

    # Create checklist for processing application
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each_with_index do |item_name, index|
      ApplicationChecklist.create!(
        application: @processing_application,
        name: item_name,
        position: index,
        completed: false
      )
    end

    @ai_agent = AiAgent.find_or_create_by(name: 'TestWorkflowAgent') do |agent|
      agent.agent_type = 'applications'
      agent.is_active = true
      agent.greeting_style = 'friendly'
    end
  end

  test "complete workflow: submitted to processing to accepted" do
    sign_in_as(@admin)

    # Step 1: Start with submitted application
    get admin_application_path(@submitted_application)
    assert_response :success
    assert_select 'h3', text: 'Application Submitted'
    assert_select 'button', text: 'Start Processing'

    # Step 2: Advance to processing
    patch advance_to_processing_admin_application_path(@submitted_application)
    assert_redirected_to admin_application_path(@submitted_application)
    follow_redirect!

    @submitted_application.reload
    assert_equal 'processing', @submitted_application.status
    assert_equal 4, @submitted_application.application_checklists.count

    # Step 3: Navigate to edit page to complete checklist
    get edit_admin_application_path(@submitted_application)
    assert_response :success
    assert_select 'h3', text: 'Processing Checklist'

    # Step 4: Complete all checklist items via AJAX
    @submitted_application.application_checklists.each do |item|
      patch update_checklist_item_admin_application_path(@submitted_application, checklist_item_id: item.id), 
            params: { completed: 'true' },
            xhr: true
      assert_response :success
    end

    # Step 5: Verify all items completed
    @submitted_application.reload
    assert @submitted_application.checklist_completed?
    assert_equal 4, @submitted_application.application_checklists.completed.count

    # Step 6: Manually set status to accepted
    patch admin_application_path(@submitted_application),
          params: { application: { status: 'accepted' } }
    assert_redirected_to admin_application_path(@submitted_application)
    follow_redirect!

    @submitted_application.reload
    assert_equal 'accepted', @submitted_application.status

    # Step 7: Verify accepted view
    assert_select '.admin-badge', text: 'Accepted'
    assert_select '.alert-success', text: 'Application Approved!'
  end

  test "checklist completion updates are logged in application versions" do
    sign_in_as(@admin)

    checklist_item = @processing_application.application_checklists.first
    initial_versions_count = @processing_application.application_versions.count

    # Complete a checklist item
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true
    assert_response :success

    # Check that application version was created
    @processing_application.reload
    assert_equal initial_versions_count + 1, @processing_application.application_versions.count

    latest_version = @processing_application.application_versions.last
    assert_equal 'checklist_updated', latest_version.action
    assert_includes latest_version.change_details, checklist_item.name
    assert_includes latest_version.change_details, 'marked as completed'
    assert_equal @admin, latest_version.user
  end

  test "cannot accept application with incomplete checklist via direct update" do
    sign_in_as(@admin)

    # Only complete 2 out of 4 checklist items
    @processing_application.application_checklists.limit(2).each do |item|
      item.mark_completed!(@admin)
    end

    # Try to update status to accepted - should fail validation
    patch admin_application_path(@processing_application),
          params: { application: { status: 'accepted' } }
    
    # Should redirect back to edit page with errors
    assert_redirected_to edit_admin_application_path(@processing_application)
    follow_redirect!

    assert_select '.alert-danger'
    assert_select '.form-errors', text: /cannot be set to accepted until all checklist items are completed/

    @processing_application.reload
    assert_equal 'processing', @processing_application.status
  end

  test "checklist items can be unchecked and progress updates correctly" do
    sign_in_as(@admin)

    # Complete all items first
    @processing_application.application_checklists.each { |item| item.mark_completed!(@admin) }
    assert @processing_application.checklist_completed?

    # Now uncheck one item
    first_item = @processing_application.application_checklists.first
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: first_item.id),
          params: { completed: 'false' },
          xhr: true
    assert_response :success

    # Verify item is now incomplete
    first_item.reload
    assert_not first_item.completed?
    assert_nil first_item.completed_at
    assert_nil first_item.completed_by

    # Verify application is no longer ready for acceptance
    @processing_application.reload
    assert_not @processing_application.checklist_completed?
    assert_equal 3, @processing_application.application_checklists.completed.count
  end

  test "turbo stream responses update the page correctly" do
    sign_in_as(@admin)
    
    get edit_admin_application_path(@processing_application)
    assert_response :success

    # Complete first checklist item via Turbo Stream
    first_item = @processing_application.application_checklists.first
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: first_item.id),
          params: { completed: 'true' },
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.content_type
    
    # Response should contain turbo-stream elements
    assert_match /<turbo-stream/, response.body
    assert_match /action="replace"/, response.body
    assert_match /target="admin-right-column"/, response.body
  end

  test "submitted application automatically creates checklist when status changed" do
    # Use a fresh submitted application
    fresh_submitted = Application.create!(
      user: @regular_user,
      address: "789 Fresh Street, Boston, MA",
      home_value: 500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 60
    )

    assert_equal 0, fresh_submitted.application_checklists.count

    # Simulate the auto-creation callback
    fresh_submitted.current_user = @admin
    fresh_submitted.update!(status: 'processing')

    fresh_submitted.reload
    assert_equal 'processing', fresh_submitted.status
    assert_equal 4, fresh_submitted.application_checklists.count

    # Verify all standard items were created
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each_with_index do |item_name, index|
      checklist_item = fresh_submitted.application_checklists.find_by(position: index)
      assert_not_nil checklist_item
      assert_equal item_name, checklist_item.name
      assert_not checklist_item.completed?
    end
  end

  test "advance to processing button creates checklist and logs change" do
    sign_in_as(@admin)

    initial_versions_count = @submitted_application.application_versions.count
    
    patch advance_to_processing_admin_application_path(@submitted_application)
    assert_redirected_to admin_application_path(@submitted_application)

    @submitted_application.reload
    
    # Should have changed status and created checklist
    assert_equal 'processing', @submitted_application.status
    assert_equal 4, @submitted_application.application_checklists.count
    
    # Should have logged the change
    assert_equal initial_versions_count + 1, @submitted_application.application_versions.count
    
    latest_version = @submitted_application.application_versions.last
    assert_equal 'status_changed', latest_version.action
    assert_includes latest_version.change_details, 'checklist created'
    assert_includes latest_version.change_details, 'Submitted'
    assert_includes latest_version.change_details, 'Processing'
  end

  test "checklist completion percentage calculation is accurate" do
    # Start with 0% completion
    assert_equal 0, @processing_application.checklist_completion_percentage

    # Complete 1 out of 4 items = 25%
    @processing_application.application_checklists.first.mark_completed!(@admin)
    assert_equal 25, @processing_application.checklist_completion_percentage

    # Complete 2 out of 4 items = 50%
    @processing_application.application_checklists.second.mark_completed!(@admin)
    assert_equal 50, @processing_application.checklist_completion_percentage

    # Complete 3 out of 4 items = 75%
    @processing_application.application_checklists.third.mark_completed!(@admin)
    assert_equal 75, @processing_application.checklist_completion_percentage

    # Complete all 4 items = 100%
    @processing_application.application_checklists.fourth.mark_completed!(@admin)
    assert_equal 100, @processing_application.checklist_completion_percentage
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    assert_redirected_to root_path
    follow_redirect!
  end
end