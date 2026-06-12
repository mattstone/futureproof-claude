require "test_helper"

class Console::EmailTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @template = email_templates(:verification_template)
  end

  # --- Email templates --------------------------------------------------------------

  test "template show renders variables and lifecycle actions" do
    get console_email_template_path(@template)

    assert_response :success
    assert_select "form[action=?]", send_test_console_email_template_path(@template)
    assert_select "form[action=?]", deactivate_console_email_template_path(@template)
  end

  test "activating a template deactivates its siblings of the same type" do
    sibling = EmailTemplate.create!(
      name: "Alt verification", subject: "Code", content: "<p>{{verification_code}}</p>",
      template_type: "verification", email_category: "operational", is_active: false
    )

    patch activate_console_email_template_path(sibling)

    assert sibling.reload.is_active?
    assert_not @template.reload.is_active?
  end

  test "preview renders with the mailer layout" do
    get preview_console_email_template_path(@template)
    assert_response :success
    assert_match "123456", response.body
  end

  test "send test delivers to the signed-in admin" do
    assert_emails 1 do
      post send_test_console_email_template_path(@template)
    end
    assert_redirected_to console_email_template_path(@template)
  end

  # --- Email workflows ------------------------------------------------------------------

  test "workflows index shows stats and table" do
    get console_email_workflows_path
    assert_response :success
    assert_select ".console-stat-label", text: "Workflows"
  end

  test "new workflow asks for a trigger first, then renders the builder" do
    get new_console_email_workflow_path
    assert_response :success
    assert_select "a", text: "User registered"

    get new_console_email_workflow_path(trigger_type: "user_registered")
    assert_select "[data-controller='console--workflow-builder']"
    assert_select "template [data-workflow-step]"
  end

  test "create workflow with nested steps" do
    assert_difference "EmailWorkflow.count", 1 do
      post console_email_workflows_path, params: {
        email_workflow: {
          name: "Welcome flow",
          description: "Greets new users",
          trigger_type: "user_registered",
          active: "0",
          trigger_conditions: { event: "user_registered" },
          workflow_steps_attributes: {
            "0" => { step_type: "send_email", position: 0, name: "Welcome email",
                     configuration: { email_template_id: @template.id.to_s } },
            "1" => { step_type: "delay", position: 1,
                     configuration: { duration: "2", unit: "days" } }
          }
        }
      }
    end

    workflow = EmailWorkflow.find_by(name: "Welcome flow")
    assert_equal 2, workflow.workflow_steps.count
    assert_equal "send_email", workflow.workflow_steps.order(:position).first.step_type
  end

  test "toggle and duplicate workflow" do
    workflow = EmailWorkflow.order(:created_at).first
    assert workflow, "needs an email workflow fixture"

    was_active = workflow.active?
    patch toggle_active_console_email_workflow_path(workflow)
    assert_equal !was_active, workflow.reload.active?

    assert_difference "EmailWorkflow.count", 1 do
      post duplicate_console_email_workflow_path(workflow)
    end
    copy = EmailWorkflow.find_by(name: "#{workflow.name} (Copy)")
    assert copy
    assert_not copy.active?
    assert_equal workflow.workflow_steps.count, copy.workflow_steps.count
  end

  test "templates library lists and creates from template" do
    get templates_console_email_workflows_path
    assert_response :success

    template_name = WorkflowTemplateService.available_templates.first[:name]
    assert_difference "EmailWorkflow.count", 1 do
      post create_from_template_console_email_workflows_path(template: template_name)
    end
  end

  test "lender admins are denied" do
    sign_in users(:lender_admin_user)
    get console_email_templates_path
    assert_redirected_to console_root_path
    get console_email_workflows_path
    assert_redirected_to console_root_path
  end
end
