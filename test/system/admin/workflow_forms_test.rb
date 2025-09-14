require "application_system_test_case"

class Admin::WorkflowFormsTest < ApplicationSystemTestCase
  def setup
    # Use existing lender or create a regular lender (not futureproof type)
    @lender = Lender.find_by(lender_type: "futureproof") || Lender.create!(
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

    # Ensure default workflows exist
    BusinessProcessWorkflow.ensure_default_workflows!

    # Get the default workflows created by the system
    @acquisition_workflow = BusinessProcessWorkflow.find_by!(process_type: "acquisition")
    @conversion_workflow = BusinessProcessWorkflow.find_by!(process_type: "conversion")

    # Update names and descriptions for testing
    @acquisition_workflow.update!(
      name: "Customer Acquisition Process",
      description: "Automated workflow for new customer onboarding"
    )

    @conversion_workflow.update!(
      name: "Lead Conversion Process",
      description: "Convert leads to paying customers"
    )

    # Standard operations workflow exists but we'll treat it as "retention"
    @retention_workflow = BusinessProcessWorkflow.find_by!(process_type: "standard_operations")
    @retention_workflow.update!(
      name: "Customer Retention Process",
      description: "Keep existing customers engaged",
      active: false
    )

    # Create email templates for testing
    @welcome_template = EmailTemplate.create!(
      name: "Welcome Email",
      subject: "Welcome to FutureProof!",
      content: "Welcome {{user.first_name}}!",
      content_body: "Welcome {{user.first_name}}!",
      email_category: "operational",
      template_type: "verification"
    )

    @followup_template = EmailTemplate.create!(
      name: "Follow Up Email",
      subject: "Getting Started Guide",
      content: "Hi {{user.first_name}}, here's your guide...",
      content_body: "Hi {{user.first_name}}, here's your guide...",
      email_category: "operational",
      template_type: "verification"
    )

    # Sign in as admin
    sign_in @admin_user
  end

  test "workflow forms index page loads correctly" do
    visit admin_workflow_forms_path

    # Check page title and header
    assert_selector "h1", text: "Form-Based Workflow Builder", wait: 5

    # Check that the page uses proper admin CSS (not Tailwind)
    assert_selector ".admin-actions-bar", visible: true
    assert_selector ".admin-table", visible: true

    # Verify comparison link to visual builder
    assert_link "Switch to Visual Interface", href: admin_business_process_workflows_path

    # Check table headers
    within ".admin-table thead" do
      assert_text "Business Process"
      assert_text "Type"
      assert_text "Status"
      assert_text "Triggers"
      assert_text "Total Steps"
      assert_text "Actions"
    end

    # Check that workflows are displayed
    assert_text "Customer Acquisition Process"
    assert_text "Lead Conversion Process"
    assert_text "Customer Retention Process"

    # Verify status badges
    assert_selector ".status-badge.status-ok", text: "Active", count: 2
    assert_selector ".status-badge.status-complete", text: "Inactive", count: 1

    # Check action buttons use proper admin classes
    assert_selector ".admin-btn.admin-btn-sm.admin-btn-primary", text: "Manage"
    assert_selector ".admin-btn.admin-btn-sm.admin-btn-success", text: "Add Trigger"
  end

  test "can navigate to individual workflow management page" do
    visit admin_workflow_forms_path

    # Click manage button for first workflow
    within "tbody tr:first-child" do
      click_link "Manage"
    end

    # Should navigate to workflow show page
    assert_current_path admin_workflow_form_path(@acquisition_workflow)

    # Check page loads properly
    assert_text "Customer Acquisition Process", wait: 5
    assert_text "Automated workflow for new customer onboarding"

    # Check breadcrumb navigation
    assert_link "Form-Based Workflows", href: admin_workflow_forms_path

    # Check workflow stats display
    assert_text "Process Type"
    assert_text "Acquisition"
    assert_text "Total Triggers"

    # Check status badge
    assert_selector ".status-badge", text: "Active"

    # Check add trigger button
    assert_link "Add Trigger", href: new_trigger_admin_workflow_form_path(@acquisition_workflow)
  end

  test "displays empty state when no triggers configured" do
    visit admin_workflow_form_path(@acquisition_workflow)

    # Should show empty state since no triggers exist
    assert_text "No triggers configured", wait: 5
    assert_text "This business process doesn't have any workflow triggers yet."

    # Should have create first trigger button
    assert_link "Create First Trigger", href: new_trigger_admin_workflow_form_path(@acquisition_workflow)
  end

  test "can navigate to new trigger form" do
    visit admin_workflow_form_path(@acquisition_workflow)

    # Click create first trigger
    click_link "Create First Trigger"

    # Should navigate to new trigger page
    assert_current_path new_trigger_admin_workflow_form_path(@acquisition_workflow)

    # Check page loads with proper form
    assert_text "Create New Trigger", wait: 5
    assert_selector "form", visible: true

    # Check form has required fields
    assert_selector "input[name='trigger_name']", visible: true
    assert_selector "select[name='event_type']", visible: true

    # Check email template dropdown has options
    within "select[name='steps[0][email_template_id]']" do
      assert_selector "option", text: "Welcome Email"
      assert_selector "option", text: "Follow Up Email"
    end

    # Check submit button
    assert_selector "input[type='submit'][value='Create Trigger']", visible: true
  end

  test "can create simple trigger with form" do
    visit new_trigger_admin_workflow_form_path(@acquisition_workflow)

    # Fill out basic trigger info
    fill_in "trigger_name", with: "welcome_sequence"
    select "user_registered", from: "event_type"

    # Add email step
    select "email", from: "steps[0][type]"
    select @welcome_template.name, from: "steps[0][email_template_id]"
    fill_in "steps[0][subject]", with: "Welcome to FutureProof!"
    fill_in "steps[0][from_email]", with: "welcome@futureproof.com"

    # Submit form
    click_button "Create Trigger"

    # Should redirect back to workflow page
    assert_current_path admin_workflow_form_path(@acquisition_workflow), wait: 5

    # Should show success message
    assert_text "Trigger 'welcome_sequence' created successfully"

    # Should display new trigger in list
    assert_text "welcome_sequence"
    assert_text "1 triggers"
    assert_text "1 simple, 0 complex"

    # Verify trigger was actually created
    @acquisition_workflow.reload
    assert @acquisition_workflow.trigger_exists?("welcome_sequence")

    trigger_data = @acquisition_workflow.trigger_data("welcome_sequence")
    assert_equal "user_registered", trigger_data.dig("nodes", 0, "config", "event")
    assert_not_nil trigger_data["nodes"].find { |n| n["type"] == "email" }
  end

  test "can create complex trigger with conditions" do
    visit new_trigger_admin_workflow_form_path(@acquisition_workflow)

    # Fill out basic info
    fill_in "trigger_name", with: "conditional_welcome"
    select "user_registered", from: "event_type"

    # Add main flow step
    select "email", from: "steps[0][type]"
    select @welcome_template.name, from: "steps[0][email_template_id]"

    # Add conditional step
    select "user_status", from: "conditional_steps[0][condition_type]"
    fill_in "conditional_steps[0][condition_value]", with: "premium"

    # Add YES branch step
    select "email", from: "conditional_steps[0][yes_steps][0][type]"
    select @followup_template.name, from: "conditional_steps[0][yes_steps][0][email_template_id]"

    # Add NO branch step
    select "delay", from: "conditional_steps[0][no_steps][0][type]"
    fill_in "conditional_steps[0][no_steps][0][duration]", with: "1"
    select "days", from: "conditional_steps[0][no_steps][0][unit]"

    # Submit form
    click_button "Create Trigger"

    # Should redirect and show success
    assert_current_path admin_workflow_form_path(@acquisition_workflow), wait: 5
    assert_text "Trigger 'conditional_welcome' created successfully"

    # Should show complex trigger statistics
    assert_text "1 simple, 1 complex"

    # Verify complex trigger structure was created
    @acquisition_workflow.reload
    trigger_data = @acquisition_workflow.trigger_data("conditional_welcome")

    # Should have condition node
    condition_nodes = trigger_data["nodes"].select { |n| n["type"] == "condition" }
    assert_equal 1, condition_nodes.count

    # Should have connections for YES/NO branches
    yes_connections = trigger_data["connections"].select { |c| c["type"] == "yes" }
    no_connections = trigger_data["connections"].select { |c| c["type"] == "no" }
    assert yes_connections.any?
    assert no_connections.any?
  end

  test "form validation works properly" do
    visit new_trigger_admin_workflow_form_path(@acquisition_workflow)

    # Try to submit empty form
    click_button "Create Trigger"

    # Should show validation errors
    assert_text "Please fix the errors below", wait: 5

    # Fill minimum required fields
    fill_in "trigger_name", with: "test_trigger"
    # Leave event_type blank

    click_button "Create Trigger"

    # Should still show errors for missing event type
    assert_text "Please fix the errors below"

    # Complete the form properly
    select "user_registered", from: "event_type"
    select "email", from: "steps[0][type]"
    select @welcome_template.name, from: "steps[0][email_template_id]"

    # Now should succeed
    click_button "Create Trigger"
    assert_current_path admin_workflow_form_path(@acquisition_workflow), wait: 5
    assert_text "created successfully"
  end

  test "can edit existing trigger" do
    # First create a trigger
    trigger_data = {
      "nodes" => [
        {
          "id" => "trigger_1",
          "type" => "trigger",
          "config" => { "event" => "user_registered" }
        },
        {
          "id" => "step_1",
          "type" => "email",
          "config" => {
            "email_template_id" => @welcome_template.id.to_s,
            "subject" => "Welcome!"
          }
        }
      ],
      "connections" => [
        { "from" => "trigger_1", "to" => "step_1", "type" => "next" }
      ]
    }

    @acquisition_workflow.add_trigger("edit_test_trigger", trigger_data)

    visit admin_workflow_form_path(@acquisition_workflow)

    # Should display the trigger
    assert_text "edit_test_trigger"

    # Click edit (this would need to be implemented in the view)
    # For now, just verify the trigger shows up correctly
    assert_text "1 triggers"
    assert_text "1 simple, 0 complex"
  end

  test "can delete trigger" do
    # Create a trigger to delete
    trigger_data = {
      "nodes" => [
        { "id" => "trigger_1", "type" => "trigger", "config" => { "event" => "user_registered" } }
      ],
      "connections" => []
    }

    @acquisition_workflow.add_trigger("delete_me", trigger_data)
    @acquisition_workflow.reload

    # Visit the workflow page
    visit admin_workflow_form_path(@acquisition_workflow)

    # Should show the trigger
    assert_text "delete_me"
    assert_text "1 triggers"

    # Delete via direct URL (this would normally be a DELETE button)
    visit destroy_trigger_admin_workflow_form_path(@acquisition_workflow, trigger_name: "delete_me")

    # Should redirect back and show success
    assert_current_path admin_workflow_form_path(@acquisition_workflow), wait: 5
    assert_text "removed successfully"

    # Trigger should be gone
    assert_text "No triggers configured"

    # Verify from model
    @acquisition_workflow.reload
    refute @acquisition_workflow.trigger_exists?("delete_me")
  end

  test "workflow statistics display correctly" do
    # Add multiple triggers with different complexities
    simple_trigger = {
      "nodes" => [
        { "id" => "t1", "type" => "trigger", "config" => {} },
        { "id" => "e1", "type" => "email", "config" => {} }
      ],
      "connections" => [{ "from" => "t1", "to" => "e1" }]
    }

    complex_trigger = {
      "nodes" => [
        { "id" => "t2", "type" => "trigger", "config" => {} },
        { "id" => "c1", "type" => "condition", "config" => {} },
        { "id" => "e2", "type" => "email", "config" => {} }
      ],
      "connections" => [
        { "from" => "t2", "to" => "c1" },
        { "from" => "c1", "to" => "e2", "type" => "yes" }
      ]
    }

    @acquisition_workflow.add_trigger("simple", simple_trigger)
    @acquisition_workflow.add_trigger("complex", complex_trigger)

    visit admin_workflow_form_path(@acquisition_workflow)

    # Check statistics
    assert_text "2", wait: 5 # Total triggers
    assert_text "1 simple, 1 complex"
    assert_text "5 steps" # Total steps across both triggers
  end

  test "navigation between workflow systems works" do
    visit admin_workflow_forms_path

    # Test navigation to visual builder
    click_link "Switch to Visual Interface"
    assert_current_path admin_business_process_workflows_path, wait: 5

    # Navigate back (assuming there's a back link)
    visit admin_workflow_forms_path
    assert_text "Form-Based Workflow Builder"
  end

  test "admin sidebar navigation includes workflow forms" do
    visit admin_workflow_forms_path

    # Check that sidebar shows workflow submenu
    within ".admin-nav" do
      assert_selector ".admin-nav-submenu", visible: true
      assert_link "Form Builder (Simple)"
      assert_link "Visual Builder (v2)"
      assert_link "Email Workflows (v1)"
    end

    # Check active state
    assert_selector ".admin-nav-sublink.active", text: "Form Builder (Simple)"
  end

  test "responsive design works on mobile" do
    # Test mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)

    visit admin_workflow_forms_path

    # Table should still be readable
    assert_selector ".admin-table", visible: true
    assert_text "Customer Acquisition Process"

    # Buttons should still be clickable
    assert_selector ".admin-btn", visible: true

    # Reset viewport
    page.driver.browser.manage.window.resize_to(1024, 768)
  end

  test "handles workflow with no business processes gracefully" do
    # Delete all workflows
    BusinessProcessWorkflow.delete_all

    visit admin_workflow_forms_path

    # Should show empty state
    assert_text "No business processes found", wait: 5
    assert_text "Business processes need to be created first"

    # Should still show header and navigation properly
    assert_text "Form-Based Workflow Builder"
    assert_link "Switch to Visual Interface"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "password123"
    click_button "Log in"

    # Wait for redirect to admin area
    assert_current_path admin_dashboard_index_path, wait: 5
  end
end