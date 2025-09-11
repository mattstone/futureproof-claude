require "application_system_test_case"

class Admin::VisualWorkflowBuilderTest < ApplicationSystemTestCase
  def setup
    # Create test lender and admin user
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      contact_email: "admin@test.com",
      country: "US"
    )
    
    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1",
      admin: true
    )
    
    # Create email templates for testing
    @email_template = EmailTemplate.create!(
      name: "Test Welcome Email",
      subject: "Welcome!",
      content: "Welcome {{user.first_name}}!",
      content_body: "Welcome {{user.first_name}}!",
      email_category: "operational",
      template_type: "verification"
    )
    
    # Sign in as admin
    sign_in @admin_user
  end
  
  test "visual workflow builder loads and displays components" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Verify visual builder is loaded
    assert_selector ".visual-workflow-builder", visible: true
    assert_selector ".component-palette", visible: true
    assert_selector ".workflow-canvas", visible: true
    assert_selector ".properties-panel", visible: true
    
    # Verify component palette items are present
    assert_selector "[data-node-type='email']", visible: true, text: "Send Email"
    assert_selector "[data-node-type='delay']", visible: true, text: "Add Delay"
    assert_selector "[data-node-type='condition']", visible: true, text: "Condition"
    assert_selector "[data-node-type='update']", visible: true, text: "Update Status"
    
    # Verify trigger type dropdown has all options
    assert_selector "select[name='email_workflow[trigger_type]']", visible: true
    
    within "select[name='email_workflow[trigger_type]']" do
      assert_selector "option[value='application_created']", text: "Application Created"
      assert_selector "option[value='application_status_changed']", text: "Application Status Changed"
      assert_selector "option[value='application_stuck_at_status']", text: "Application Stuck at Status"
      assert_selector "option[value='contract_status_changed']", text: "Contract Status Changed"
      assert_selector "option[value='contract_stuck_at_status']", text: "Contract Stuck at Status"
      assert_selector "option[value='user_registered']", text: "User Registered"
      assert_selector "option[value='document_uploaded']", text: "Document Uploaded"
      assert_selector "option[value='contract_signed']", text: "Contract Signed"
      assert_selector "option[value='inactivity']", text: "Inactivity Detected"
      assert_selector "option[value='time_delay']", text: "Time Delay"
    end
  end
  
  test "dragging component palette works" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for JavaScript to load
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Verify palette can be dragged (check for draggable functionality)
    palette = find(".component-palette")
    assert palette.visible?
    
    # Check that the palette has draggable styling
    assert_selector ".component-palette[style*='cursor: move'], .component-palette .palette-header", wait: 3
  end
  
  test "trigger type selection updates conditions via Hotwire" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for page to load
    assert_selector "turbo-frame#trigger-conditions-frame", wait: 5
    
    # Select a trigger type
    select "Application Created", from: "email_workflow[trigger_type]"
    
    # Wait for Turbo Frame to update with conditions
    assert_selector "turbo-frame#trigger-conditions-frame", wait: 10
    
    # Check that trigger conditions section appears
    within "turbo-frame#trigger-conditions-frame" do
      # The specific conditions will depend on the trigger type
      # For now, just verify the frame updates
      assert_text "Application", wait: 5
    end
    
    # Try another trigger type
    select "User Registered", from: "email_workflow[trigger_type]"
    
    # Wait for frame update
    within "turbo-frame#trigger-conditions-frame" do
      assert_text "User", wait: 5
    end
  end
  
  test "quick action buttons work" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for JavaScript controller to connect
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Fill in basic workflow info first
    fill_in "email_workflow[name]", with: "Test Quick Actions Workflow"
    select "User Registered", from: "email_workflow[trigger_type]"
    
    # Wait for trigger conditions to load
    sleep 1
    
    # Test Quick Email button
    click_button "Quick Email"
    
    # Verify an email node appears on canvas
    assert_selector ".workflow-node", wait: 5
    assert_selector ".workflow-node[data-node-type='email']", wait: 3
    
    # Test Quick Delay button  
    click_button "Quick Delay"
    
    # Verify a delay node appears
    assert_selector ".workflow-node[data-node-type='delay']", wait: 3
    
    # Test Quick Condition button
    click_button "Quick Condition"
    
    # Verify a condition node appears
    assert_selector ".workflow-node[data-node-type='condition']", wait: 3
  end
  
  test "zoom controls work" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for controller to load
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Test zoom in
    click_button class: "zoom-btn", text: "+"
    
    # Verify zoom level changes
    zoom_display = find(".zoom-level")
    assert_not_equal "100%", zoom_display.text
    
    # Test reset zoom
    click_button title: "Reset Zoom (0)"
    
    # Should return to 100%
    assert_equal "100%", zoom_display.text
  end
  
  test "panel toggles work" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Verify panels are visible initially
    assert_selector ".component-palette", visible: true
    assert_selector ".properties-panel", visible: true
    
    # Toggle left panel (component palette)
    find(".left-panel-toggle").click
    
    # Palette should be hidden
    assert_selector ".component-palette", visible: false
    
    # Toggle right panel (properties)
    find(".right-panel-toggle").click
    
    # Properties should be hidden
    assert_selector ".properties-panel", visible: false
    
    # Toggle back
    find(".left-panel-toggle").click
    assert_selector ".component-palette", visible: true
    
    find(".right-panel-toggle").click
    assert_selector ".properties-panel", visible: true
  end
  
  test "workflow form submission works with visual builder data" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for JavaScript
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Fill in workflow details
    fill_in "email_workflow[name]", with: "Test Visual Workflow"
    fill_in "email_workflow[description]", with: "Testing visual builder submission"
    select "User Registered", from: "email_workflow[trigger_type]"
    check "email_workflow[active]"
    
    # Wait for trigger conditions
    sleep 1
    
    # Add a quick email step
    click_button "Quick Email"
    
    # Wait for node to appear
    assert_selector ".workflow-node[data-node-type='email']", wait: 3
    
    # Submit the form
    click_button "Create Workflow"
    
    # Should redirect to workflow show page
    assert_current_path %r{/admin/email_workflows/\d+}
    assert_text "Test Visual Workflow"
    assert_text "has been created successfully"
    
    # Verify workflow was created
    workflow = EmailWorkflow.find_by(name: "Test Visual Workflow")
    assert_not_nil workflow
    assert_equal "user_registered", workflow.trigger_type
    assert workflow.active?
  end
  
  test "keyboard shortcuts work" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for JavaScript
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Test zoom in with + key
    find("body").send_keys "+"
    zoom_display = find(".zoom-level")
    refute_equal "100%", zoom_display.text
    
    # Test reset zoom with 0 key
    find("body").send_keys "0"
    assert_equal "100%", zoom_display.text
    
    # Test fit to content with F key
    find("body").send_keys "f"
    # Should trigger fit-to-content (zoom may change)
    sleep 0.5 # Give time for zoom to update
  end
  
  test "workflow builder maintains state during form interactions" do
    visit new_admin_email_workflow_path(builder: "visual")
    
    # Wait for JavaScript
    assert_selector "[data-controller='workflow-builder']", wait: 5
    
    # Fill basic info
    fill_in "email_workflow[name]", with: "State Test Workflow"
    select "Application Created", from: "email_workflow[trigger_type]"
    
    # Wait for conditions to load
    sleep 1
    
    # Add some nodes
    click_button "Quick Email"
    click_button "Quick Delay"
    
    # Verify nodes exist
    assert_selector ".workflow-node", count: 2, wait: 3
    
    # Change trigger type - should preserve nodes
    select "User Registered", from: "email_workflow[trigger_type]"
    
    # Wait for Turbo update
    sleep 1
    
    # Nodes should still exist
    assert_selector ".workflow-node", count: 2
    
    # Zoom should still work
    click_button class: "zoom-btn", text: "+"
    zoom_display = find(".zoom-level")
    refute_equal "100%", zoom_display.text
  end
  
  private
  
  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    click_button "Log in"
  end
end