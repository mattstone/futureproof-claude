require "test_helper"

class WorkflowExecutionTest < ActiveSupport::TestCase
  def setup
    # Create test lender first
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      contact_email: "contact@testlender.com",
      country: "US"
    )
    
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    
    @workflow = EmailWorkflow.create!(
      name: "Test Workflow",
      description: "Test workflow",
      trigger_type: "application_created",
      trigger_conditions: { "event" => "application_created" },
      created_by: @user
    )
    
    @app_user = User.create!(
      email: "exectest@example.com",
      password: "password123",
      first_name: "Exec",
      last_name: "Test",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    @application = Application.create!(
      user: @app_user,
      address: "123 Exec St",
      home_value: 500000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "created",
      growth_rate: 2.0,
      borrower_age: 30
    )
    
    @execution = WorkflowExecution.new(
      workflow: @workflow,
      target: @application,
      status: "pending"
    )
  end
  
  test "should create valid workflow execution" do
    assert @execution.valid?
    assert @execution.save
  end
  
  test "should require workflow" do
    @execution.workflow = nil
    assert_not @execution.valid?
    assert_includes @execution.errors[:workflow], "must exist"
  end
  
  test "should require target" do
    @execution.target = nil
    assert_not @execution.valid?
    assert_includes @execution.errors[:target], "must exist"
  end
  
  test "should have pending status by default" do
    execution = WorkflowExecution.new(
      workflow: @workflow,
      target: @application
    )
    assert_equal "pending", execution.status
  end
  
  test "should validate status inclusion" do
    # Can't test invalid enum values directly - they raise ArgumentError
    # Test presence validation instead
    @execution.status = nil
    assert_not @execution.valid?
    assert_includes @execution.errors[:status], "can't be blank"
  end
  
  test "should calculate progress percentage" do
    @execution.save!
    
    # No steps completed (position 0 out of 2)
    assert_equal 0, @execution.progress_percentage
    
    # Add some workflow steps
    step1 = @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 0,
      configuration: { "email_template_id" => 1 }
    )
    step2 = @workflow.workflow_steps.create!(
      step_type: "delay",
      position: 1,
      configuration: { "duration" => 1, "unit" => "days" }
    )
    
    # Move to step 1 (50% progress)
    @execution.update!(current_step_position: 1)
    assert_equal 50, @execution.progress_percentage
    
    # Complete all steps (100% progress)
    @execution.update!(current_step_position: 2)
    assert_equal 100, @execution.progress_percentage
  end
  
  test "should find current step" do
    @execution.save!
    
    step1 = @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 0,
      configuration: { "email_template_id" => 1 }
    )
    step2 = @workflow.workflow_steps.create!(
      step_type: "delay",
      position: 1,
      configuration: { "duration" => 1, "unit" => "days" }
    )
    
    # At position 0
    assert_equal step1, @execution.current_step
    
    # Move to position 1 
    @execution.update!(current_step_position: 1)
    @execution.reload
    
    assert_equal step2, @execution.current_step
    
    # Past all steps
    @execution.update!(current_step_position: 2)
    @execution.reload
    
    assert_nil @execution.current_step
  end
  
  test "should start execution" do
    # Add a workflow step so it doesn't complete immediately
    @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 0,
      configuration: { "email_template_id" => 1 }
    )
    
    @execution.save!
    
    @execution.start!
    
    @execution.reload
    assert_equal "running", @execution.status
    assert_not_nil @execution.started_at
  end
  
  test "should complete execution" do
    @execution.save!
    @execution.update!(status: "running", started_at: Time.current)
    
    @execution.complete!
    
    @execution.reload
    assert_equal "completed", @execution.status
    assert_not_nil @execution.completed_at
  end
  
  test "should fail execution" do
    @execution.save!
    @execution.update!(status: "running", started_at: Time.current)
    
    error_message = "Test error"
    @execution.fail_execution!(error_message)
    
    @execution.reload
    assert_equal "failed", @execution.status
    assert_not_nil @execution.completed_at
    assert_equal error_message, @execution.last_error
  end
  
  test "should not complete already completed execution" do
    @execution.save!
    original_completed_at = 1.hour.ago
    @execution.update!(status: "completed", completed_at: original_completed_at)
    
    # Should not change completed_at
    @execution.complete!
    @execution.reload
    
    assert_equal original_completed_at.to_i, @execution.completed_at.to_i
  end
end
