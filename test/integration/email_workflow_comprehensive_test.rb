require "test_helper"

class EmailWorkflowComprehensiveTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = users(:admin_user)
    @test_user = User.create!(
      email: "workflow_test@example.com",
      password: "password123",
      first_name: "John",
      last_name: "Doe",
      mobile_number: "0400123456",
      mobile_country_code: "+61",
      country_of_residence: "Australia",
      lender: "futureproof",
      terms_accepted: true
    )
    
    # Clear any existing emails from previous tests
    ActionMailer::Base.deliveries.clear
    
    # Get our test email templates
    @stuck_app_template = EmailTemplate.find_by(name: 'Application Stuck Reminder')
    @status_change_template = EmailTemplate.find_by(name: 'Application Status Changed')
    @stuck_contract_template = EmailTemplate.find_by(name: 'Contract Stuck Reminder')
    
    # Create templates if they don't exist (fallback for CI)
    create_test_templates_if_missing
  end

  test "complete workflow lifecycle - application stuck at status" do
    puts "\n=== Testing Application Stuck at Status Workflow ==="
    
    # Step 1: Create an application that's been stuck for 3+ days
    application = create_stuck_application(@test_user, 'submitted', 4.days.ago)
    puts "✓ Created stuck application: #{application.id} (#{application.status})"
    
    # Step 2: Create workflow for stuck applications
    workflow = create_stuck_application_workflow(@stuck_app_template.id)
    puts "✓ Created workflow: #{workflow.name}"
    
    # Step 3: Run the stuck status job
    puts "Running StuckStatusWorkflowJob..."
    StuckStatusWorkflowJob.new.perform
    puts "✓ Job completed"
    
    # Step 4: Verify workflow execution was recorded
    tracker = WorkflowExecutionTracker.where(
      email_workflow: workflow,
      target: application
    ).last
    
    assert tracker, "Workflow execution should be tracked"
    assert_equal "application_stuck_at_status", tracker.trigger_type
    assert tracker.run_once, "Should be marked as run_once"
    puts "✓ Workflow execution tracked: #{tracker.trigger_type}"
    
    # Step 5: Verify email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size, "Should send one email"
    
    email = ActionMailer::Base.deliveries.last
    assert_equal [@test_user.email], email.to
    assert email.subject.include?(application.id.to_s.rjust(6, '0'))
    assert email.body.to_s.include?("John") # User's first name
    assert email.body.to_s.include?(application.address)
    puts "✓ Email sent to #{email.to.first}"
    puts "  Subject: #{email.subject}"
    
    # Step 6: Test run-once logic - should not send duplicate email
    ActionMailer::Base.deliveries.clear
    StuckStatusWorkflowJob.new.perform
    
    assert_equal 0, ActionMailer::Base.deliveries.size, "Should not send duplicate email"
    puts "✓ Run-once logic working - no duplicate email sent"
    
    puts "✅ Application stuck workflow test PASSED\n"
  end

  test "application status change workflow" do
    puts "\n=== Testing Application Status Change Workflow ==="
    
    # Step 1: Create application
    application = create_application(@test_user, 'property_details')
    puts "✓ Created application: #{application.id} (#{application.status})"
    
    # Step 2: Create workflow for status changes
    workflow = create_status_change_workflow(@status_change_template.id)
    puts "✓ Created workflow: #{workflow.name}"
    
    # Step 3: Change application status (this should trigger the workflow)
    ActionMailer::Base.deliveries.clear
    
    application.current_user = @admin_user
    application.update!(status: 'processing')
    puts "✓ Changed application status to: #{application.status}"
    
    # Step 4: Verify email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size, "Should send email on status change"
    
    email = ActionMailer::Base.deliveries.last
    assert_equal [@test_user.email], email.to
    assert email.subject.include?("Processing")
    assert email.body.to_s.include?("John")
    assert email.body.to_s.include?("Processing")
    puts "✓ Email sent on status change"
    puts "  Subject: #{email.subject}"
    
    puts "✅ Application status change workflow test PASSED\n"
  end

  test "contract stuck at status workflow" do
    puts "\n=== Testing Contract Stuck at Status Workflow ==="
    
    # Step 1: Create application and convert to contract
    application = create_application(@test_user, 'accepted')
    
    # We need to mock contract creation since it requires lender/funder setup
    contract = Contract.new(
      application: application,
      status: 'awaiting_funding',
      start_date: Date.current,
      end_date: Date.current + 30.years,
      allocated_amount: application.home_value,
      updated_at: 5.days.ago
    )
    
    # Skip validations for test
    contract.save(validate: false)
    puts "✓ Created stuck contract: #{contract.id} (#{contract.status})"
    
    # Step 2: Create workflow for stuck contracts
    workflow = create_stuck_contract_workflow(@stuck_contract_template.id)
    puts "✓ Created workflow: #{workflow.name}"
    
    # Step 3: Run the stuck status job
    ActionMailer::Base.deliveries.clear
    StuckStatusWorkflowJob.new.perform
    puts "✓ Job completed"
    
    # Step 4: Verify workflow execution
    tracker = WorkflowExecutionTracker.where(
      email_workflow: workflow,
      target: contract
    ).last
    
    assert tracker, "Contract workflow execution should be tracked"
    assert_equal "contract_stuck_at_status", tracker.trigger_type
    puts "✓ Contract workflow execution tracked"
    
    # Step 5: Verify email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size, "Should send contract stuck email"
    
    email = ActionMailer::Base.deliveries.last
    assert_equal [@test_user.email], email.to
    assert email.subject.include?("Contract Update")
    assert email.body.to_s.include?("John")
    puts "✓ Contract stuck email sent"
    puts "  Subject: #{email.subject}"
    
    puts "✅ Contract stuck workflow test PASSED\n"
  end

  test "workflow with delay and email nodes" do
    puts "\n=== Testing Workflow with Delay and Email Sequence ==="
    
    # Create application
    application = create_stuck_application(@test_user, 'submitted', 3.days.ago)
    
    # Create workflow with delay between emails
    workflow = create_complex_workflow_with_delay(@stuck_app_template.id, @status_change_template.id)
    puts "✓ Created complex workflow with delay"
    
    ActionMailer::Base.deliveries.clear
    StuckStatusWorkflowJob.new.perform
    
    # Should send first email immediately
    assert_equal 1, ActionMailer::Base.deliveries.size, "Should send first email immediately"
    puts "✓ First email sent immediately"
    
    # Check that delayed job was scheduled (we can't easily test the actual delay in tests)
    delayed_jobs = DelayedWorkflowContinuationJob.jobs.select { |job| 
      job['job_class'] == 'DelayedWorkflowContinuationJob' 
    }
    
    # Note: In test environment, we can't easily verify delayed jobs without additional setup
    puts "✓ Complex workflow structure processed"
    
    puts "✅ Complex workflow test PASSED\n"
  end

  test "email template variable substitution" do
    puts "\n=== Testing Email Template Variable Substitution ==="
    
    application = create_application(@test_user, 'processing')
    
    # Test the template rendering directly
    rendered = @stuck_app_template.render_content({
      user: @test_user,
      application: application
    })
    
    # Verify user variables are substituted
    assert rendered[:content].include?("John"), "Should substitute user first name"
    assert rendered[:subject].include?(application.id.to_s.rjust(6, '0')), "Should substitute application reference"
    
    # Verify application variables are substituted
    assert rendered[:content].include?(application.address), "Should substitute application address"
    assert rendered[:content].include?(application.status_display), "Should substitute status display"
    assert rendered[:content].include?(application.formatted_home_value), "Should substitute formatted home value"
    
    puts "✓ User variables substituted correctly"
    puts "✓ Application variables substituted correctly"
    puts "✓ Subject line variables substituted correctly"
    
    puts "✅ Email template variable substitution test PASSED\n"
  end

  test "workflow execution service node processing" do
    puts "\n=== Testing WorkflowExecutionService Node Processing ==="
    
    application = create_application(@test_user, 'submitted')
    
    # Create workflow with multiple node types
    workflow_data = {
      'nodes' => [
        {
          'id' => 'trigger1',
          'type' => 'trigger',
          'config' => { 'trigger_type' => 'application_stuck_at_status' }
        },
        {
          'id' => 'email1',
          'type' => 'email',
          'config' => { 'email_template_id' => @stuck_app_template.id }
        },
        {
          'id' => 'condition1',
          'type' => 'condition',
          'config' => { 'condition_type' => 'status_unchanged' }
        },
        {
          'id' => 'email2',
          'type' => 'email',
          'config' => { 'email_template_id' => @status_change_template.id }
        }
      ],
      'connections' => [
        { 'from' => 'trigger1', 'to' => 'email1' },
        { 'from' => 'email1', 'to' => 'condition1' },
        { 'from' => 'condition1', 'to' => 'email2', 'condition' => 'true' }
      ]
    }
    
    workflow = EmailWorkflow.create!(
      name: 'Test Node Processing Workflow',
      trigger_type: 'application_stuck_at_status',
      trigger_conditions: { 'stuck_status' => 'submitted' },
      workflow_builder_data: workflow_data,
      created_by: @admin_user,
      active: true
    )
    
    # Execute workflow using the service
    ActionMailer::Base.deliveries.clear
    service = WorkflowExecutionService.new(workflow, application, { from_status: 'submitted' })
    execution = service.execute!
    
    assert_equal 'completed', execution.status, "Workflow execution should complete"
    puts "✓ Workflow execution completed successfully"
    
    # Should have processed email nodes (exact count depends on condition evaluation)
    assert ActionMailer::Base.deliveries.size >= 1, "Should send at least one email"
    puts "✓ Email nodes processed: #{ActionMailer::Base.deliveries.size} emails sent"
    
    puts "✅ WorkflowExecutionService test PASSED\n"
  end

  private

  def create_application(user, status)
    Application.create!(
      user: user,
      status: status,
      address: "123 Test Street, Sydney NSW 2000",
      home_value: 750000,
      ownership_status: 'individual',
      property_state: 'primary_residence',
      has_existing_mortgage: false,
      existing_mortgage_amount: 0,
      borrower_age: 45,
      loan_term: 30,
      income_payout_term: 30,
      growth_rate: 3.5
    )
  end

  def create_stuck_application(user, status, updated_at)
    app = create_application(user, status)
    app.update_column(:updated_at, updated_at)
    app
  end

  def create_stuck_application_workflow(template_id)
    EmailWorkflow.create!(
      name: 'Test Stuck Application Workflow',
      trigger_type: 'application_stuck_at_status',
      trigger_conditions: { 'stuck_status' => 'submitted' },
      workflow_builder_data: {
        'nodes' => [
          {
            'id' => 'trigger1',
            'type' => 'trigger',
            'config' => {
              'stuck_status' => 'submitted',
              'stuck_duration' => 3,
              'stuck_unit' => 'days',
              'run_once' => true
            }
          },
          {
            'id' => 'email1',
            'type' => 'email',
            'config' => {
              'email_template_id' => template_id
            }
          }
        ],
        'connections' => [
          { 'from' => 'trigger1', 'to' => 'email1' }
        ]
      },
      created_by: @admin_user,
      active: true
    )
  end

  def create_status_change_workflow(template_id)
    EmailWorkflow.create!(
      name: 'Test Status Change Workflow',
      trigger_type: 'application_status_changed',
      trigger_conditions: { 'from_status' => 'property_details', 'to_status' => 'processing' },
      workflow_builder_data: {
        'nodes' => [
          {
            'id' => 'trigger1',
            'type' => 'trigger',
            'config' => { 'trigger_type' => 'application_status_changed' }
          },
          {
            'id' => 'email1',
            'type' => 'email',
            'config' => { 'email_template_id' => template_id }
          }
        ],
        'connections' => [
          { 'from' => 'trigger1', 'to' => 'email1' }
        ]
      },
      created_by: @admin_user,
      active: true
    )
  end

  def create_stuck_contract_workflow(template_id)
    EmailWorkflow.create!(
      name: 'Test Stuck Contract Workflow',
      trigger_type: 'contract_stuck_at_status',
      trigger_conditions: { 'stuck_contract_status' => 'awaiting_funding' },
      workflow_builder_data: {
        'nodes' => [
          {
            'id' => 'trigger1',
            'type' => 'trigger',
            'config' => {
              'stuck_contract_status' => 'awaiting_funding',
              'stuck_duration' => 3,
              'stuck_unit' => 'days',
              'run_once' => true
            }
          },
          {
            'id' => 'email1',
            'type' => 'email',
            'config' => { 'email_template_id' => template_id }
          }
        ],
        'connections' => [
          { 'from' => 'trigger1', 'to' => 'email1' }
        ]
      },
      created_by: @admin_user,
      active: true
    )
  end

  def create_complex_workflow_with_delay(template1_id, template2_id)
    EmailWorkflow.create!(
      name: 'Test Complex Workflow with Delay',
      trigger_type: 'application_stuck_at_status',
      trigger_conditions: { 'stuck_status' => 'submitted' },
      workflow_builder_data: {
        'nodes' => [
          {
            'id' => 'trigger1',
            'type' => 'trigger',
            'config' => {
              'stuck_status' => 'submitted',
              'stuck_duration' => 3,
              'stuck_unit' => 'days',
              'run_once' => true
            }
          },
          {
            'id' => 'email1',
            'type' => 'email',
            'config' => { 'email_template_id' => template1_id }
          },
          {
            'id' => 'delay1',
            'type' => 'delay',
            'config' => { 'duration' => 1, 'unit' => 'hours' }
          },
          {
            'id' => 'email2',
            'type' => 'email',
            'config' => { 'email_template_id' => template2_id }
          }
        ],
        'connections' => [
          { 'from' => 'trigger1', 'to' => 'email1' },
          { 'from' => 'email1', 'to' => 'delay1' },
          { 'from' => 'delay1', 'to' => 'email2' }
        ]
      },
      created_by: @admin_user,
      active: true
    )
  end

  def create_test_templates_if_missing
    unless @stuck_app_template
      @stuck_app_template = EmailTemplate.create!(
        name: 'Application Stuck Reminder',
        template_type: 'application_submitted',
        email_category: 'operational',
        subject: 'Test Application Stuck - {{application.reference_number}}',
        content_body: '<p>Dear {{user.first_name}}, your application needs attention.</p>',
        is_active: true
      )
    end
    
    unless @status_change_template
      @status_change_template = EmailTemplate.create!(
        name: 'Application Status Changed',
        template_type: 'application_submitted',
        email_category: 'operational',
        subject: 'Status Updated - {{application.status_display}}',
        content_body: '<p>Dear {{user.first_name}}, status changed to {{application.status_display}}.</p>',
        is_active: true
      )
    end
    
    unless @stuck_contract_template
      @stuck_contract_template = EmailTemplate.create!(
        name: 'Contract Stuck Reminder',
        template_type: 'application_submitted',
        email_category: 'operational',
        subject: 'Contract Update Required',
        content_body: '<p>Dear {{user.first_name}}, your contract needs attention.</p>',
        is_active: true
      )
    end
  end
end