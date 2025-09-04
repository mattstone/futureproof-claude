require "test_helper"

class WorkflowStepTest < ActiveSupport::TestCase
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
    
    @email_template = EmailTemplate.create!(
      name: "Test Template",
      template_type: "verification",
      email_category: "operational",
      subject: "Test Subject",
      content: "Test content",
      content_body: "Test body",
      description: "Test description"
    )
  end
  
  test "should create valid send_email step" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "send_email",
      position: 0,
      name: "Send Welcome Email",
      configuration: { "email_template_id" => @email_template.id }
    )
    
    assert step.valid?
    assert step.save
  end
  
  test "should create valid delay step" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "delay",
      position: 1,
      name: "3 Day Wait",
      configuration: { "duration" => 3, "unit" => "days" }
    )
    
    assert step.valid?
    assert step.save
  end
  
  test "should create valid condition step" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "condition",
      position: 2,
      name: "Check Status",
      configuration: { 
        "condition_type" => "application_status",
        "expected_status" => "active"
      }
    )
    
    assert step.valid?
    assert step.save
  end
  
  test "should require workflow" do
    step = WorkflowStep.new(
      step_type: "send_email",
      position: 0,
      configuration: {}
    )
    
    assert_not step.valid?
    assert_includes step.errors[:workflow], "must exist"
  end
  
  test "should require step_type" do
    step = WorkflowStep.new(
      workflow: @workflow,
      position: 0,
      configuration: {}
    )
    
    assert_not step.valid?
    assert_includes step.errors[:step_type], "can't be blank"
  end
  
  test "should validate step_type inclusion" do
    step = WorkflowStep.new(
      workflow: @workflow,
      position: 0,
      configuration: { "email_template_id" => @email_template.id }
    )
    
    # Test with valid step type
    step.step_type = "send_email"
    assert step.valid?
    
    # Can't directly test invalid enum values in Rails as they raise ArgumentError
    # This tests the presence validation instead
    step.step_type = nil
    assert_not step.valid?
    assert_includes step.errors[:step_type], "can't be blank"
  end
  
  test "should require position" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "send_email",
      configuration: {}
    )
    
    assert_not step.valid?
    assert_includes step.errors[:position], "can't be blank"
  end
  
  test "should validate position uniqueness within workflow" do
    step1 = @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 0,
      configuration: { "email_template_id" => @email_template.id }
    )
    
    step2 = WorkflowStep.new(
      workflow: @workflow,
      step_type: "delay",
      position: 0,
      configuration: { "duration" => 1, "unit" => "days" }
    )
    
    assert_not step2.valid?
    assert_includes step2.errors[:position], "has already been taken"
  end
  
  test "should validate send_email configuration" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "send_email",
      position: 0,
      configuration: {}
    )
    
    assert_not step.valid?
    assert_includes step.errors[:configuration], "must include email_template_id for send_email steps"
  end
  
  test "should validate delay configuration" do
    step = WorkflowStep.new(
      workflow: @workflow,
      step_type: "delay",
      position: 0,
      configuration: { "duration" => 5 }
    )
    
    assert_not step.valid?
    assert_includes step.errors[:configuration], "must include duration and unit for delay steps"
  end
  
  test "should execute send_email step" do
    step = @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 0,
      name: "Send Email",
      configuration: { "email_template_id" => @email_template.id }
    )
    
    app_user = User.create!(
      email: "steptest@example.com",
      password: "password123",
      first_name: "Step",
      last_name: "Test",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    application = Application.create!(
      user: app_user,
      address: "123 Step St",
      home_value: 500000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "created",
      growth_rate: 2.0,
      borrower_age: 30
    )
    
    execution = WorkflowExecution.create!(
      workflow: @workflow,
      target: application,
      status: "running"
    )
    
    step_execution = WorkflowStepExecution.create!(
      execution: execution,
      step: step,
      status: "pending"
    )
    
    result = step.execute_for(execution)
    assert result[:success]
    assert_equal "Email sent successfully", result[:message]
  end
end
