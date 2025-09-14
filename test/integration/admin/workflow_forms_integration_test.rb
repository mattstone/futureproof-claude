require "test_helper"

class Admin::WorkflowFormsIntegrationTest < ActionDispatch::IntegrationTest
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
      terms_accepted: true,
      admin: true,
      confirmed_at: Time.current
    )

    @non_admin_user = User.create!(
      email: "user@test.com",
      password: "password123",
      first_name: "Regular",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: true,
      admin: false,
      confirmed_at: Time.current
    )

    # Ensure default workflows exist, then find or create unique test workflow
    BusinessProcessWorkflow.ensure_default_workflows!
    @workflow = BusinessProcessWorkflow.find_by(process_type: "acquisition") ||
      BusinessProcessWorkflow.create!(
        name: "Test Workflow",
        description: "Test workflow for integration testing",
        process_type: "acquisition",
        workflow_data: { triggers: {} },
        active: true
      )

    # Create email templates
    @email_template = EmailTemplate.create!(
      name: "Test Email Template",
      subject: "Test Subject",
      content: "Test content",
      content_body: "Test content body",
      email_category: "operational",
      template_type: "verification"
    )

    sign_in @admin_user
  end

  test "GET /admin/workflow_forms requires admin authentication" do
    sign_out
    get admin_workflow_forms_path

    assert_redirected_to new_user_session_path
  end

  test "GET /admin/workflow_forms denies access to non-admin users" do
    sign_out
    sign_in @non_admin_user

    get admin_workflow_forms_path
    assert_response :forbidden
  end

  test "GET /admin/workflow_forms displays workflow index" do
    get admin_workflow_forms_path

    assert_response :success
    assert_select "h1", text: "Form-Based Workflow Builder"
    assert_select ".admin-table"
    assert_select "td", text: "Test Workflow"
    assert_select ".status-badge", text: "Active"
  end

  test "GET /admin/workflow_forms calculates correct statistics" do
    # Add some triggers to test stats
    simple_trigger = {
      "nodes" => [
        { "id" => "t1", "type" => "trigger", "config" => {} },
        { "id" => "e1", "type" => "email", "config" => {} }
      ],
      "connections" => []
    }

    complex_trigger = {
      "nodes" => [
        { "id" => "t2", "type" => "trigger", "config" => {} },
        { "id" => "c1", "type" => "condition", "config" => {} },
        { "id" => "e2", "type" => "email", "config" => {} },
        { "id" => "e3", "type" => "email", "config" => {} }
      ],
      "connections" => []
    }

    @workflow.add_trigger("simple", simple_trigger)
    @workflow.add_trigger("complex", complex_trigger)

    get admin_workflow_forms_path

    assert_response :success

    # Check that statistics are calculated correctly
    assert_select "td", text: "2 triggers"
    assert_select "td", text: "1 simple, 1 complex"
    assert_select "td", text: "6 steps" # 2 + 4 steps total
  end

  test "GET /admin/workflow_forms/:id shows workflow details" do
    get admin_workflow_form_path(@workflow)

    assert_response :success
    assert_select "h1", text: "Test Workflow"
    assert_select "p", text: "Test workflow for integration testing"
    assert_select ".status-badge", text: "Active"
  end

  test "GET /admin/workflow_forms/:id with triggers shows trigger list" do
    # Add a trigger
    trigger_data = {
      "nodes" => [
        {
          "id" => "trigger_1",
          "type" => "trigger",
          "config" => { "event" => "user_registered" }
        },
        {
          "id" => "email_1",
          "type" => "email",
          "config" => { "email_template_id" => @email_template.id }
        }
      ],
      "connections" => [
        { "from" => "trigger_1", "to" => "email_1", "type" => "next" }
      ]
    }

    @workflow.add_trigger("welcome_sequence", trigger_data)

    get admin_workflow_form_path(@workflow)

    assert_response :success
    assert_select "h3", text: "Simple Workflows (1)"
    assert_select "td", text: "1" # Total triggers
    assert_select "td", text: "2" # Total steps
  end

  test "GET /admin/workflow_forms/:id/new_trigger shows trigger form" do
    get new_trigger_admin_workflow_form_path(@workflow)

    assert_response :success
    assert_select "form"
    assert_select "input[name='trigger_name']"
    assert_select "select[name='event_type']"
    assert_select "select[name='steps[0][email_template_id]']"
    assert_select "input[type='submit'][value='Create Trigger']"

    # Check email template options are present
    assert_select "option", text: "Test Email Template"
  end

  test "POST /admin/workflow_forms/:id/create_trigger creates simple trigger" do
    trigger_params = {
      trigger_name: "test_trigger",
      event_type: "user_registered",
      steps: [
        {
          type: "email",
          email_template_id: @email_template.id,
          subject: "Welcome Email",
          from_email: "test@example.com"
        }
      ]
    }

    post create_trigger_admin_workflow_form_path(@workflow), params: trigger_params

    assert_redirected_to admin_workflow_form_path(@workflow)
    assert_equal "Trigger 'test_trigger' created successfully", flash[:success]

    # Verify trigger was created
    @workflow.reload
    assert @workflow.trigger_exists?("test_trigger")

    trigger_data = @workflow.trigger_data("test_trigger")
    assert_equal "user_registered", trigger_data.dig("nodes", 0, "config", "event")

    # Should have trigger and email nodes
    assert_equal 2, trigger_data["nodes"].count
    assert trigger_data["nodes"].any? { |n| n["type"] == "trigger" }
    assert trigger_data["nodes"].any? { |n| n["type"] == "email" }

    # Should have connection
    assert_equal 1, trigger_data["connections"].count
  end

  test "POST /admin/workflow_forms/:id/create_trigger creates complex trigger with conditions" do
    trigger_params = {
      trigger_name: "complex_trigger",
      event_type: "application_status_changed",
      steps: [
        {
          type: "email",
          email_template_id: @email_template.id,
          subject: "Status Changed"
        }
      ],
      conditional_steps: [
        {
          condition_type: "user_status",
          condition_value: "premium",
          yes_steps: [
            {
              type: "email",
              email_template_id: @email_template.id,
              subject: "Premium Welcome"
            }
          ],
          no_steps: [
            {
              type: "delay",
              duration: "1",
              unit: "days"
            }
          ]
        }
      ]
    }

    post create_trigger_admin_workflow_form_path(@workflow), params: trigger_params

    assert_redirected_to admin_workflow_form_path(@workflow)
    assert_equal "Trigger 'complex_trigger' created successfully", flash[:success]

    # Verify complex trigger structure
    @workflow.reload
    trigger_data = @workflow.trigger_data("complex_trigger")

    # Should have multiple node types
    node_types = trigger_data["nodes"].map { |n| n["type"] }.uniq.sort
    assert_includes node_types, "trigger"
    assert_includes node_types, "email"
    assert_includes node_types, "condition"

    # Should have different connection types
    connection_types = trigger_data["connections"].map { |c| c["type"] }.uniq.sort
    assert_includes connection_types, "next"
    assert_includes connection_types, "yes"
    assert_includes connection_types, "no"
  end

  test "POST /admin/workflow_forms/:id/create_trigger validates required fields" do
    # Missing trigger name
    trigger_params = {
      event_type: "user_registered",
      steps: [{ type: "email", email_template_id: @email_template.id }]
    }

    post create_trigger_admin_workflow_form_path(@workflow), params: trigger_params

    assert_response :success # Re-renders form
    assert_equal "Please fix the errors below", flash[:error]
  end

  test "POST /admin/workflow_forms/:id/create_trigger validates trigger data structure" do
    # Invalid trigger data (missing nodes)
    trigger_params = {
      trigger_name: "invalid_trigger"
      # Missing event_type and steps
    }

    post create_trigger_admin_workflow_form_path(@workflow), params: trigger_params

    assert_response :success # Re-renders form
    assert_equal "Please fix the errors below", flash[:error]

    # Verify trigger was not created
    @workflow.reload
    refute @workflow.trigger_exists?("invalid_trigger")
  end

  test "GET /admin/workflow_forms/:id/edit_trigger shows edit form" do
    # Create a trigger to edit
    trigger_data = {
      "nodes" => [
        {
          "id" => "trigger_1",
          "type" => "trigger",
          "config" => { "event" => "user_registered" }
        },
        {
          "id" => "email_1",
          "type" => "email",
          "config" => {
            "email_template_id" => @email_template.id.to_s,
            "subject" => "Original Subject"
          }
        }
      ],
      "connections" => []
    }

    @workflow.add_trigger("edit_test", trigger_data)

    get edit_trigger_admin_workflow_form_path(@workflow, trigger_name: "edit_test")

    assert_response :success
    assert_select "form"
    assert_select "input[name='trigger_name'][value='edit_test']", count: 0 # Name should be in URL
    assert_select "select[name='event_type']"

    # Should pre-populate form with existing data
    assert_select "option[selected][value='user_registered']"
  end

  test "PUT /admin/workflow_forms/:id/update_trigger updates existing trigger" do
    # Create initial trigger
    trigger_data = {
      "nodes" => [
        { "id" => "trigger_1", "type" => "trigger", "config" => { "event" => "user_registered" } },
        { "id" => "email_1", "type" => "email", "config" => { "email_template_id" => @email_template.id.to_s } }
      ],
      "connections" => []
    }

    @workflow.add_trigger("update_test", trigger_data)

    # Update the trigger
    update_params = {
      trigger_name: "update_test",
      event_type: "application_created", # Changed
      steps: [
        {
          type: "email",
          email_template_id: @email_template.id,
          subject: "Updated Subject"
        }
      ]
    }

    put update_trigger_admin_workflow_form_path(@workflow, trigger_name: "update_test"), params: update_params

    assert_redirected_to admin_workflow_form_path(@workflow)
    assert_equal "Trigger 'update_test' updated successfully", flash[:success]

    # Verify changes
    @workflow.reload
    updated_data = @workflow.trigger_data("update_test")
    assert_equal "application_created", updated_data.dig("nodes", 0, "config", "event")
  end

  test "DELETE /admin/workflow_forms/:id/destroy_trigger removes trigger" do
    # Create trigger to delete
    trigger_data = {
      "nodes" => [
        { "id" => "trigger_1", "type" => "trigger", "config" => {} }
      ],
      "connections" => []
    }

    @workflow.add_trigger("delete_test", trigger_data)

    # Verify it exists
    assert @workflow.trigger_exists?("delete_test")

    # Delete it
    delete destroy_trigger_admin_workflow_form_path(@workflow, trigger_name: "delete_test")

    assert_redirected_to admin_workflow_form_path(@workflow)
    assert_equal "Trigger 'delete_test' removed successfully", flash[:success]

    # Verify it's gone
    @workflow.reload
    refute @workflow.trigger_exists?("delete_test")
  end

  test "DELETE /admin/workflow_forms/:id/destroy_trigger handles non-existent trigger" do
    delete destroy_trigger_admin_workflow_form_path(@workflow, trigger_name: "nonexistent")

    assert_redirected_to admin_workflow_form_path(@workflow)
    assert_equal "Trigger not found", flash[:error]
  end

  test "workflow forms export system comparison data" do
    get admin_workflow_forms_path

    assert_response :success

    # Check that comparison file is created
    comparison_file = Rails.root.join("tmp/workflow_system_comparison.json")
    assert File.exist?(comparison_file), "System comparison file should be created"

    # Verify file contains expected structure
    comparison_data = JSON.parse(File.read(comparison_file))
    assert comparison_data.key?("timestamp")
    assert comparison_data.key?("system_comparison")
    assert comparison_data.key?("current_data")

    # Check system comparison data
    assert comparison_data["system_comparison"].key?("visual_system")
    assert comparison_data["system_comparison"].key?("form_system")

    # Check that it includes workflow statistics
    assert comparison_data["current_data"].key?("total_workflows")
  end

  test "helper methods work correctly" do
    # Test node_color_class helper
    controller = Admin::WorkflowFormsController.new

    # FIXED: Remove Tailwind CSS violations
    assert_equal "admin-node-trigger", controller.send(:node_color_class, "trigger")
    assert_equal "admin-node-email", controller.send(:node_color_class, "email")
    assert_equal "admin-node-delay", controller.send(:node_color_class, "delay")
    assert_equal "admin-node-condition", controller.send(:node_color_class, "condition")
    assert_equal "admin-node-webhook", controller.send(:node_color_class, "webhook")
    assert_equal "admin-node-unknown", controller.send(:node_color_class, "unknown")

    # Test has_conditions? helper
    simple_data = { "nodes" => [{ "type" => "email" }] }
    complex_data = { "nodes" => [{ "type" => "condition" }] }

    refute controller.send(:has_conditions?, simple_data)
    assert controller.send(:has_conditions?, complex_data)
    refute controller.send(:has_conditions?, {})
    refute controller.send(:has_conditions?, { "nodes" => nil })
  end

  test "ensures admin access control works" do
    # Test that regular users can't access any workflow form pages
    sign_out
    sign_in @non_admin_user

    get admin_workflow_forms_path
    assert_response :forbidden

    get admin_workflow_form_path(@workflow)
    assert_response :forbidden

    get new_trigger_admin_workflow_form_path(@workflow)
    assert_response :forbidden

    post create_trigger_admin_workflow_form_path(@workflow)
    assert_response :forbidden
  end

  # 🚨 CRITICAL: MANDATORY 7-STEP TESTING PROTOCOL 🚨
  test "EXPERT INTEGRATION TEST: full workflow forms system with HTTP verification" do
    # STEP 1: WRITE CODE - Already implemented

    # STEP 2: WRITE INTEGRATION TEST - This test covers actual HTTP requests

    # STEP 3: RUN INTEGRATION TEST - Execute with actual HTTP requests
    get admin_workflow_forms_path
    assert_response :success

    # STEP 4: TEST ACTUAL URLS - Verify all routes work with real HTTP
    get admin_workflow_form_path(@workflow)
    assert_response :success

    get new_trigger_admin_workflow_form_path(@workflow)
    assert_response :success

    # STEP 5: VERIFY HTML RENDERS - Confirm no template/method errors
    get admin_workflow_forms_path
    assert_response :success
    assert_match /Form-Based Workflow Builder/, response.body
    assert_match /admin-table/, response.body, "Custom CSS classes must be present"
    assert_match /status-badge/, response.body, "Status badges must render"
    refute_match /text-\w+-\d+/, response.body, "CRITICAL: No Tailwind classes allowed!"
    refute_match /bg-\w+-\d+/, response.body, "CRITICAL: No Tailwind classes allowed!"
    refute_match /flex/, response.body, "CRITICAL: No Tailwind classes allowed!"

    # STEP 6: TEST USER INTERACTIONS - Forms, links, buttons work
    # Test form submission
    trigger_params = {
      trigger_name: "integration_test_trigger",
      event_type: "user_registered",
      steps: [{
        type: "email",
        email_template_id: @email_template.id,
        subject: "Integration Test Email"
      }]
    }

    post create_trigger_admin_workflow_form_path(@workflow), params: trigger_params
    assert_redirected_to admin_workflow_form_path(@workflow)
    follow_redirect!
    assert_response :success
    assert_match /integration_test_trigger/, response.body

    # Test edit form
    get edit_trigger_admin_workflow_form_path(@workflow, trigger_name: "integration_test_trigger")
    assert_response :success
    assert_match /form/, response.body

    # Test delete action
    delete destroy_trigger_admin_workflow_form_path(@workflow, trigger_name: "integration_test_trigger")
    assert_redirected_to admin_workflow_form_path(@workflow)

    # STEP 7: ONLY THEN CLAIM SUCCESS - All steps completed successfully
    assert true, "✅ EXPERT INTEGRATION TEST PASSED: Full HTTP cycle verified"
  end

  test "EXPERT INTEGRATION TEST: CSS framework compliance verification" do
    # Test all workflow pages for CSS violations
    pages_to_test = [
      admin_workflow_forms_path,
      admin_workflow_form_path(@workflow),
      new_trigger_admin_workflow_form_path(@workflow)
    ]

    pages_to_test.each do |page_path|
      get page_path
      assert_response :success

      # CRITICAL: Verify no external CSS frameworks
      refute_match /text-\w+-\d+/, response.body, "FORBIDDEN: Tailwind text- classes in #{page_path}"
      refute_match /bg-\w+-\d+/, response.body, "FORBIDDEN: Tailwind bg- classes in #{page_path}"
      refute_match /space-x-\d+/, response.body, "FORBIDDEN: Tailwind space- classes in #{page_path}"
      refute_match /gap-\d+/, response.body, "FORBIDDEN: Tailwind gap- classes in #{page_path}"
      refute_match /mb-\d+/, response.body, "FORBIDDEN: Tailwind margin classes in #{page_path}"
      refute_match /px-\d+/, response.body, "FORBIDDEN: Tailwind padding classes in #{page_path}"
      refute_match /class="[^"]*\bbtn-primary\b/, response.body, "FORBIDDEN: Bootstrap button classes in #{page_path}"
      refute_match /class="[^"]*\bcontainer\b/, response.body, "FORBIDDEN: Bootstrap container classes in #{page_path}"
      refute_match /class="[^"]*\brow\b/, response.body, "FORBIDDEN: Bootstrap row classes in #{page_path}"
      refute_match /class="[^"]*\bcol-\d+\b/, response.body, "FORBIDDEN: Bootstrap col classes in #{page_path}"

      # REQUIRED: Verify custom admin CSS classes are used
      assert_match /admin-/, response.body, "REQUIRED: Custom admin- CSS classes must be present in #{page_path}"
    end

    assert true, "✅ CSS FRAMEWORK COMPLIANCE VERIFIED: No external frameworks detected"
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
  end

  def sign_out
    delete destroy_user_session_path
  end
end