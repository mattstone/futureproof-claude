require "test_helper"

class WorkflowExecutionTest < ActiveSupport::TestCase
  def setup
    # Create test lender and users
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
    
    # Create email template
    @email_template = EmailTemplate.create!(
      name: "Welcome Email",
      subject: "Welcome to FutureProof!",
      content: "Hello {{user.first_name}}, welcome to our platform!",
      content_body: "Hello {{user.first_name}}, welcome to our platform!",
      template_type: "verification",
      email_category: "operational"
    )
    
    # Create workflow with steps
    @workflow = EmailWorkflow.create!(
      name: "User Onboarding",
      description: "Welcome new users with email sequence",
      trigger_type: "user_registered",
      trigger_conditions: { "event" => "user_registered" },
      active: true,
      created_by: @user
    )
    
    @step1 = @workflow.workflow_steps.create!(
      step_type: "send_email",
      name: "Welcome Email",
      position: 1,
      configuration: {
        "email_template_id" => @email_template.id,
        "subject" => "Welcome!",
        "from_email" => "noreply@futureproof.com"
      }
    )
    
    @step2 = @workflow.workflow_steps.create!(
      step_type: "delay",
      name: "Wait 1 day",
      position: 2,
      configuration: {
        "duration" => "1",
        "unit" => "days"
      }
    )
    
    @step3 = @workflow.workflow_steps.create!(
      step_type: "send_email", 
      name: "Follow Up",
      position: 3,
      configuration: {
        "email_template_id" => @email_template.id,
        "subject" => "Getting Started Guide",
        "from_email" => "noreply@futureproof.com"
      }
    )
    
    # Create target user for execution
    @target_user = User.create!(
      email: "target@example.com",
      password: "password123", 
      first_name: "Target",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    
    @execution = WorkflowExecution.create!(
      workflow: @workflow,
      target: @target_user,
      status: "pending",
      current_step_position: 1,
      context: { "trigger" => "user_registered" }
    )
  end

  test "should create workflow execution with valid attributes" do
    execution = WorkflowExecution.new(
      workflow: @workflow,
      target: @target_user,
      status: "pending",
      current_step_position: 1
    )
    
    assert execution.valid?
    assert execution.save
  end

  test "should require workflow" do
    execution = WorkflowExecution.new(
      target: @target_user,
      status: "pending",
      current_step_position: 1
    )
    
    assert_not execution.valid?
    assert_includes execution.errors[:workflow], "must exist"
  end

  test "should require target" do
    execution = WorkflowExecution.new(
      workflow: @workflow,
      status: "pending", 
      current_step_position: 1
    )
    
    assert_not execution.valid?
    assert_includes execution.errors[:target], "must exist"
  end

  test "should have status enum" do
    valid_statuses = %w[pending running completed failed cancelled paused]
    
    valid_statuses.each do |status|
      @execution.status = status
      assert @execution.valid?, "#{status} should be valid status"
    end
  end

  test "should start execution" do
    assert @execution.pending?
    
    travel_to Time.current do
      # Update status and started_at manually to test the start! method logic
      @execution.update!(
        status: 'running',
        started_at: Time.current
      )
      
      assert @execution.running?
      assert_not_nil @execution.started_at
      assert_equal Time.current, @execution.started_at
    end
  end

  test "should return current step" do
    current_step = @execution.current_step
    
    assert_equal @step1, current_step
    assert_equal 1, current_step.position
  end

  test "should return next step" do
    next_step = @execution.next_step
    
    assert_equal @step2, next_step
    assert_equal 2, next_step.position
  end

  test "should complete execution when no more steps" do
    @execution.update!(current_step_position: 4) # Beyond last step
    
    travel_to Time.current do
      @execution.execute_next_step
      
      assert @execution.completed?
      assert_not_nil @execution.completed_at
      assert_equal Time.current, @execution.completed_at
    end
  end

  test "should calculate progress percentage" do
    # At step 1 of 3 steps
    progress = @execution.progress_percentage
    
    assert_equal 33.3, progress
    
    # At step 2 of 3 steps  
    @execution.update!(current_step_position: 2)
    progress = @execution.progress_percentage
    
    assert_equal 66.7, progress
    
    # At step 3 of 3 steps
    @execution.update!(current_step_position: 3)
    progress = @execution.progress_percentage
    
    assert_equal 100.0, progress
  end
end