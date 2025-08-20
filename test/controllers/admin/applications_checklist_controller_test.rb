require 'test_helper'

class Admin::ApplicationsChecklistControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      first_name: "Admin",
      last_name: "Controller",
      email: "admin-controller@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @regular_user = User.create!(
      first_name: "John",
      last_name: "Doe", 
      email: "user-controller@example.com",
      password: "password123",
      password_confirmation: "password123",
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )

    @processing_application = Application.create!(
      user: @regular_user,
      address: "123 Controller Street, Portland, OR",
      home_value: 800000,
      status: 'processing',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 65
    )

    # Create checklist items
    @checklist_items = ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.map.with_index do |item_name, index|
      ApplicationChecklist.create!(
        application: @processing_application,
        name: item_name,
        position: index,
        completed: false
      )
    end

    @ai_agent = AiAgent.find_or_create_by(name: 'TestControllerAgent') do |agent|
      agent.agent_type = 'applications'
      agent.is_active = true
      agent.greeting_style = 'friendly'
    end

    sign_in_as(@admin)
  end

  test "update_checklist_item marks item as completed" do
    checklist_item = @checklist_items.first
    assert_not checklist_item.completed?

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true

    assert_response :success
    
    checklist_item.reload
    assert checklist_item.completed?
    assert_not_nil checklist_item.completed_at
    assert_equal @admin, checklist_item.completed_by
  end

  test "update_checklist_item marks item as incomplete" do
    # Start with completed item
    checklist_item = @checklist_items.first
    checklist_item.mark_completed!(@admin)
    assert checklist_item.completed?

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'false' },
          xhr: true

    assert_response :success
    
    checklist_item.reload
    assert_not checklist_item.completed?
    assert_nil checklist_item.completed_at
    assert_nil checklist_item.completed_by
  end

  test "update_checklist_item creates application version log" do
    checklist_item = @checklist_items.first
    initial_versions_count = @processing_application.application_versions.count

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true

    assert_response :success
    
    @processing_application.reload
    assert_equal initial_versions_count + 1, @processing_application.application_versions.count
    
    latest_version = @processing_application.application_versions.last
    assert_equal 'checklist_updated', latest_version.action
    assert_includes latest_version.change_details, checklist_item.name
    assert_includes latest_version.change_details, 'marked as completed'
    assert_equal @admin, latest_version.user
  end

  test "update_checklist_item responds with turbo stream" do
    checklist_item = @checklist_items.first

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html', response.content_type
    
    # Should contain turbo-stream replacement for right column
    assert_match /<turbo-stream action="replace" target="admin-right-column">/, response.body
    assert_match /data-controller="checklist"/, response.body
  end

  test "update_checklist_item returns 404 for non-existent checklist item" do
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: 99999),
          params: { completed: 'true' },
          xhr: true

    assert_response :not_found
  end

  test "update_checklist_item returns 404 for non-existent application" do
    assert_raises(ActiveRecord::RecordNotFound) do
      patch update_checklist_item_admin_application_path(99999, checklist_item_id: @checklist_items.first.id),
            params: { completed: 'true' },
            xhr: true
    end
  end

  test "advance_to_processing changes submitted application to processing" do
    submitted_app = Application.create!(
      user: @regular_user,
      address: "456 Submitted Lane, Seattle, WA",
      home_value: 600000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 67
    )

    patch advance_to_processing_admin_application_path(submitted_app)

    assert_redirected_to admin_application_path(submitted_app)
    
    submitted_app.reload
    assert_equal 'processing', submitted_app.status
    assert_equal 4, submitted_app.application_checklists.count
  end

  test "advance_to_processing fails for non-submitted application" do
    # Try to advance processing application (should fail)
    patch advance_to_processing_admin_application_path(@processing_application)

    assert_redirected_to admin_application_path(@processing_application)
    follow_redirect!
    
    assert_match /Application must be submitted to advance to processing/, flash[:alert]
    
    @processing_application.reload
    assert_equal 'processing', @processing_application.status # Unchanged
  end

  test "advance_to_processing creates checklist and logs change" do
    submitted_app = Application.create!(
      user: @regular_user,
      address: "789 Advance Street, Denver, CO",
      home_value: 750000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 62
    )

    initial_versions_count = submitted_app.application_versions.count

    patch advance_to_processing_admin_application_path(submitted_app)

    submitted_app.reload
    
    # Should create checklist
    assert_equal 4, submitted_app.application_checklists.count
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each_with_index do |item_name, index|
      checklist_item = submitted_app.application_checklists.find_by(position: index)
      assert_equal item_name, checklist_item.name
      assert_not checklist_item.completed?
    end

    # Should log the change
    assert_equal initial_versions_count + 1, submitted_app.application_versions.count
    latest_version = submitted_app.application_versions.last
    assert_equal 'status_changed', latest_version.action
    assert_includes latest_version.change_details, 'checklist created'
  end

  test "show action displays checklist for processing application" do
    get admin_application_path(@processing_application)
    
    assert_response :success
    assert_select 'h3', text: 'Processing Checklist'
    assert_select '.checklist-item', count: 4
    assert_select '.progress-text', text: /0 of 4 completed/
    
    # All checkboxes should be disabled (read-only view)
    assert_select 'input[type=checkbox][disabled]', count: 4
  end

  test "edit action displays editable checklist for processing application" do
    get edit_admin_application_path(@processing_application)
    
    assert_response :success
    assert_select 'h3', text: 'Processing Checklist'
    assert_select '.checklist-item', count: 4
    assert_select '.progress-text', text: /0 of 4 completed/
    
    # Checkboxes should be enabled (editable view)
    assert_select 'input[type=checkbox]:not([disabled])', count: 4
    assert_select 'form[data-controller="checklist"]'
  end

  test "show action displays submitted application advance button" do
    submitted_app = Application.create!(
      user: @regular_user,
      address: "321 Show Street, Austin, TX",
      home_value: 900000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 58
    )

    get admin_application_path(submitted_app)
    
    assert_response :success
    assert_select 'h3', text: 'Application Submitted'
    assert_select 'button', text: 'Start Processing'
    assert_select 'p', text: /This application is ready to be processed/
  end

  test "edit action shows correct status options based on checklist completion" do
    # Test with incomplete checklist
    get edit_admin_application_path(@processing_application)
    
    assert_response :success
    assert_select 'select[name="application[status]"] option[value="processing"]'
    assert_select 'select[name="application[status]"] option[value="rejected"]'
    assert_select 'select[name="application[status]"] option[value="accepted"]', count: 0
    assert_select '.form-help-text', text: /Complete all checklist items to enable "Accepted" status/

    # Complete all checklist items
    @checklist_items.each { |item| item.mark_completed!(@admin) }

    get edit_admin_application_path(@processing_application)
    
    assert_response :success
    assert_select 'select[name="application[status]"] option[value="processing"]'
    assert_select 'select[name="application[status]"] option[value="rejected"]'
    assert_select 'select[name="application[status]"] option[value="accepted"]', count: 1
    assert_select '.form-help-text', text: /All checklist items completed. Application can be accepted/
  end

  test "regular users cannot access checklist functionality" do
    sign_out
    sign_in_as(@regular_user)

    # Should not be able to access admin application pages
    get admin_application_path(@processing_application)
    assert_redirected_to new_user_session_path

    get edit_admin_application_path(@processing_application) 
    assert_redirected_to new_user_session_path

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: @checklist_items.first.id),
          params: { completed: 'true' },
          xhr: true
    assert_redirected_to new_user_session_path
  end

  test "update_checklist_item sets flash notice" do
    checklist_item = @checklist_items.first

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true

    assert_response :success
    assert_equal "Checklist item marked as completed.", flash[:notice]
  end

  test "update_checklist_item handles both checked and unchecked states" do
    checklist_item = @checklist_items.first

    # Test checking
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true

    assert_response :success
    checklist_item.reload
    assert checklist_item.completed?

    # Test unchecking
    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'false' },
          xhr: true

    assert_response :success
    checklist_item.reload
    assert_not checklist_item.completed?
  end

  test "required instance variables are set for turbo stream responses" do
    checklist_item = @checklist_items.first

    patch update_checklist_item_admin_application_path(@processing_application, checklist_item_id: checklist_item.id),
          params: { completed: 'true' },
          xhr: true

    assert_response :success
    
    # Controller should set required instance variables for messaging interface
    assert assigns(:ai_agents)
    assert assigns(:messages)
    assert assigns(:new_message)
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end

  def sign_out
    delete destroy_user_session_path
  end
end