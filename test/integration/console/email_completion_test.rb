require "test_helper"

class Console::EmailCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @template = EmailTemplate.first!
    @workflow = EmailWorkflow.first || EmailWorkflow.create!(
      name: "EM1 Test Workflow", trigger_type: "user_registered",
      trigger_conditions: {}, active: true, created_by: users(:admin_user)
    )
  end

  # --- Template → workflow cross-reference ------------------------------------------

  test "template page lists workflows that reference it" do
    step_for(@workflow, @template)

    get console_email_template_path(@template)
    assert_select ".console-card-title", text: "Used by workflows"
    assert_select "a", text: @workflow.name
  end

  test "deactivating a template referenced by an active workflow is blocked" do
    step_for(@workflow, @template)
    @workflow.update_columns(active: true)
    @template.update_columns(is_active: true)

    patch deactivate_console_email_template_path(@template)
    assert_match(/Cannot deactivate.*#{Regexp.escape(@workflow.name)}/, flash[:alert])
    assert @template.reload.is_active?
  end

  test "deactivating an unreferenced template still works" do
    WorkflowStep.of_type(:send_email)
                .select { |s| s.configuration["email_template_id"].to_s == @template.id.to_s }
                .each(&:destroy!)
    @template.update_columns(is_active: true)

    patch deactivate_console_email_template_path(@template)
    assert_not @template.reload.is_active?
  end

  # --- Execution visibility -----------------------------------------------------------

  test "workflow page shows execution stats and per-run step results" do
    execution = WorkflowExecution.create!(workflow: @workflow, target: users(:regular_user),
                                          status: "completed", started_at: 1.hour.ago, completed_at: 30.minutes.ago)
    step = step_for(@workflow, @template)
    WorkflowStepExecution.create!(execution: execution, step: step,
                                  status: "completed", completed_at: 30.minutes.ago)

    get console_email_workflow_path(@workflow)
    assert_select ".console-stat-label", text: "Total runs"
    assert_select ".console-stat-label", text: "Success rate"
    assert_select ".console-execution-steps li", minimum: 1
  end

  test "active executions can be cancelled, audited" do
    execution = WorkflowExecution.create!(workflow: @workflow, target: users(:regular_user),
                                          status: "running", started_at: 5.minutes.ago)

    assert_difference -> { AuditLog.where(action: "workflow_execution_cancelled").count }, 1 do
      post cancel_execution_console_email_workflow_path(@workflow, execution_id: execution.id)
    end
    assert_equal "cancelled", execution.reload.status
  end

  test "workflow with active executions cannot be deleted" do
    WorkflowExecution.create!(workflow: @workflow, target: users(:regular_user),
                              status: "running", started_at: 5.minutes.ago)

    assert_no_difference -> { EmailWorkflow.count } do
      delete console_email_workflow_path(@workflow)
    end
    assert_match(/Cannot delete/, flash[:alert])
  end

  test "index shows when each workflow last ran" do
    WorkflowExecution.create!(workflow: @workflow, target: users(:regular_user),
                              status: "completed", started_at: 2.days.ago, completed_at: 2.days.ago)

    get console_email_workflows_path
    assert_select "th", text: "Last run"
    assert_match(/ago|never/, response.body)
  end

  private

  def step_for(workflow, template)
    position = (workflow.workflow_steps.maximum(:position) || -1) + 1
    workflow.workflow_steps.create!(step_type: "send_email", position: position,
                                    name: "Send #{template.name}",
                                    configuration: { "email_template_id" => template.id })
  end
end
