require "test_helper"

class EmailWorkflowTest < ActiveSupport::TestCase
  def setup
    # Create test lender first
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      contact_email: "contact@testlender.com",
      country: "US"
    )
    
    # Create test user directly to avoid fixture issues
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    
    @workflow = EmailWorkflow.new(
      name: "Test Application Workflow",
      description: "Test workflow for application creation",
      trigger_type: "application_created",
      trigger_conditions: { "event" => "application_created" },
      created_by: @user
    )
  end
  
  test "should create valid email workflow" do
    assert @workflow.valid?
    assert @workflow.save
  end
  
  test "should require name" do
    @workflow.name = nil
    assert_not @workflow.valid?
    assert_includes @workflow.errors[:name], "can't be blank"
  end
  
  test "should require trigger_type" do
    @workflow.trigger_type = nil
    assert_not @workflow.valid?
    assert_includes @workflow.errors[:trigger_type], "can't be blank"
  end
  
  test "should be active by default" do
    assert @workflow.active?
  end
  
  test "should have workflow_steps association" do
    @workflow.save!
    step = @workflow.workflow_steps.create!(
      step_type: "send_email",
      position: 1,
      configuration: { email_template_id: 1 }
    )
    
    assert_equal 1, @workflow.workflow_steps.count
    assert_equal step, @workflow.workflow_steps.first
  end
  
  test "can_trigger_for? should work for application_created" do
    @workflow.trigger_type = "application_created"
    @workflow.trigger_conditions = { "event" => "application_created" }
    @workflow.save!
    
    app_user = User.create!(
      email: "john@example.com",
      password: "password123",
      first_name: "John",
      last_name: "Doe",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    application = Application.create!(
      user: app_user,
      address: "123 Test St",
      home_value: 500000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "created",
      growth_rate: 2.0,
      borrower_age: 30
    )
    assert @workflow.can_trigger_for?(application)
    
    # Should not trigger for other types
    assert_not @workflow.can_trigger_for?(@user)
  end
  
  test "can_trigger_for? should work for application_status_changed" do
    @workflow.trigger_type = "application_status_changed" 
    @workflow.trigger_conditions = { "from_status" => "created" }
    @workflow.save!
    
    app_user2 = User.create!(
      email: "jane@example.com",
      password: "password123",
      first_name: "Jane",
      last_name: "Doe",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    application = Application.create!(
      user: app_user2,
      address: "456 Test Ave",
      home_value: 600000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "submitted",
      growth_rate: 2.0,
      borrower_age: 35
    )
    assert @workflow.can_trigger_for?(application, from_status: "created")
    assert_not @workflow.can_trigger_for?(application, from_status: "submitted")
  end
  
  test "execute_for should create workflow execution" do
    @workflow.save!
    app_user3 = User.create!(
      email: "bob@example.com",
      password: "password123",
      first_name: "Bob",
      last_name: "Smith",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    application = Application.create!(
      user: app_user3,
      address: "789 Test Blvd",
      home_value: 700000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "created",
      growth_rate: 2.0,
      borrower_age: 40
    )
    
    execution = @workflow.execute_for(application)
    
    assert_not_nil execution
    assert_equal @workflow, execution.workflow
    assert_equal application, execution.target
    assert_equal "pending", execution.status
  end
  
  test "inactive workflows should not trigger" do
    @workflow.active = false
    @workflow.trigger_conditions = { "event" => "application_created" }
    @workflow.save!
    
    app_user4 = User.create!(
      email: "alice@example.com",
      password: "password123",
      first_name: "Alice",
      last_name: "Johnson",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    application = Application.create!(
      user: app_user4,
      address: "321 Test Dr",
      home_value: 450000,
      ownership_status: "individual",
      property_state: "primary_residence",
      status: "created",
      growth_rate: 2.0,
      borrower_age: 28
    )
    execution = @workflow.execute_for(application)
    
    assert_nil execution
  end
end
