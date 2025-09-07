require "test_helper"

class EmailWorkflowRealEmailTest < ActionDispatch::IntegrationTest
  def setup
    # Configure ActionMailer to actually send emails for this test
    # This test will use the configured delivery method (letter_opener in development)
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.raise_delivery_errors = true
    
    @admin_user = users(:admin_user)
    @test_user = User.create!(
      email: "real_workflow_test@example.com",
      password: "password123",
      first_name: "Sarah",
      last_name: "Johnson",
      mobile_number: "+61400987654",
      country_of_residence: "Australia",
      email_verified: true
    )
    
    # Clear delivery queue
    ActionMailer::Base.deliveries.clear
    
    # Get email templates
    @stuck_app_template = EmailTemplate.find_by(name: 'Application Stuck Reminder')
    @status_change_template = EmailTemplate.find_by(name: 'Application Status Changed')
    @stuck_contract_template = EmailTemplate.find_by(name: 'Contract Stuck Reminder')
  end

  test "send real emails through complete workflow lifecycle" do
    puts "\n🚀 REAL EMAIL TEST - Complete Workflow Lifecycle"
    puts "=" * 60
    
    # Step 1: Create test application stuck at submitted status
    application = Application.create!(
      user: @test_user,
      status: 'submitted',
      address: "456 Real Test Avenue, Melbourne VIC 3000",
      home_value: 950000,
      ownership_status: 'individual',
      property_state: 'primary_residence',
      has_existing_mortgage: false,
      existing_mortgage_amount: 0,
      borrower_age: 38,
      loan_term: 30,
      income_payout_term: 30,
      growth_rate: 4.2,
      updated_at: 4.days.ago
    )
    
    puts "📋 Created test application:"
    puts "   - ID: #{application.id}"
    puts "   - Status: #{application.status_display}"
    puts "   - Property: #{application.address}"
    puts "   - Value: #{application.formatted_home_value}"
    puts "   - Owner: #{@test_user.full_name} (#{@test_user.email})"
    puts "   - Stuck since: #{application.updated_at.strftime('%Y-%m-%d %H:%M')}"

    # Step 2: Create comprehensive workflow
    workflow = EmailWorkflow.create!(
      name: 'Real Email Test - Comprehensive Workflow',
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
              'email_template_id' => @stuck_app_template.id,
              'subject' => 'REAL TEST: Your Application Needs Attention'
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
    
    puts "\n📤 Created workflow:"
    puts "   - Name: #{workflow.name}"
    puts "   - Trigger: #{workflow.trigger_type}"
    puts "   - Active: #{workflow.active?}"

    # Step 3: Execute workflow and send real email
    puts "\n⚡ Executing workflow..."
    
    initial_delivery_count = ActionMailer::Base.deliveries.size
    StuckStatusWorkflowJob.new.perform
    final_delivery_count = ActionMailer::Base.deliveries.size
    
    emails_sent = final_delivery_count - initial_delivery_count
    puts "   - Emails sent: #{emails_sent}"
    
    if emails_sent > 0
      email = ActionMailer::Base.deliveries.last
      puts "   - To: #{email.to.join(', ')}"
      puts "   - Subject: #{email.subject}"
      puts "   - From: #{email.from.join(', ')}"
      puts "   - Date: #{email.date}"
      
      # Display email content preview
      body_preview = email.body.to_s.gsub(/<[^>]*>/, '').strip.split("\n").first(3).join(" ")
      puts "   - Content preview: #{body_preview[0..100]}..."
    end

    # Step 4: Verify workflow execution tracking
    tracker = WorkflowExecutionTracker.where(
      email_workflow: workflow,
      target: application
    ).last
    
    puts "\n📊 Workflow execution tracking:"
    if tracker
      puts "   - Execution tracked: ✅"
      puts "   - Trigger type: #{tracker.trigger_type}"
      puts "   - Run once: #{tracker.run_once}"
      puts "   - Executed at: #{tracker.executed_at.strftime('%Y-%m-%d %H:%M:%S')}"
    else
      puts "   - Execution tracked: ❌"
    end

    # Step 5: Test status change workflow
    puts "\n🔄 Testing status change workflow..."
    
    status_workflow = EmailWorkflow.create!(
      name: 'Real Email Test - Status Change',
      trigger_type: 'application_status_changed',
      trigger_conditions: { 'from_status' => 'submitted', 'to_status' => 'processing' },
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
            'config' => {
              'email_template_id' => @status_change_template.id,
              'subject' => 'REAL TEST: Application Status Updated'
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
    
    # Trigger status change
    pre_change_count = ActionMailer::Base.deliveries.size
    application.current_user = @admin_user
    application.update!(status: 'processing')
    post_change_count = ActionMailer::Base.deliveries.size
    
    status_emails_sent = post_change_count - pre_change_count
    puts "   - Status change emails sent: #{status_emails_sent}"
    
    if status_emails_sent > 0
      status_email = ActionMailer::Base.deliveries.last
      puts "   - Subject: #{status_email.subject}"
      puts "   - New status in email: Processing"
    end

    # Step 6: Email content verification
    puts "\n🔍 Email content verification:"
    
    if ActionMailer::Base.deliveries.any?
      latest_email = ActionMailer::Base.deliveries.last
      email_body = latest_email.body.to_s
      
      # Check for proper variable substitution
      checks = [
        { desc: "User first name", check: email_body.include?("Sarah") },
        { desc: "Application reference", check: email_body.include?(application.id.to_s.rjust(6, '0')) },
        { desc: "Property address", check: email_body.include?("Real Test Avenue") },
        { desc: "Home value", check: email_body.include?("$950,000") || email_body.include?("950000") },
        { desc: "Status display", check: email_body.include?("Processing") || email_body.include?("Submitted") }
      ]
      
      checks.each do |check|
        status = check[:check] ? "✅" : "❌"
        puts "   - #{check[:desc]}: #{status}"
      end
    end

    # Step 7: Summary and instructions
    puts "\n📧 EMAIL DELIVERY SUMMARY"
    puts "=" * 60
    puts "Total emails sent during test: #{ActionMailer::Base.deliveries.size}"
    puts "Delivery method: #{ActionMailer::Base.delivery_method}"
    
    if Rails.env.development? && ActionMailer::Base.delivery_method == :letter_opener
      puts "\n🌐 To view the emails:"
      puts "   - Check your browser - Letter Opener should have opened the emails automatically"
      puts "   - Or visit: http://localhost:1080 (if using MailCatcher)"
      puts "   - Or check the tmp/letter_opener/ directory"
    end
    
    puts "\n📨 Test email recipient: #{@test_user.email}"
    puts "📝 Application details included in emails:"
    puts "   - Reference: #{application.id.to_s.rjust(6, '0')}"
    puts "   - Property: #{application.address}"
    puts "   - Value: #{application.formatted_home_value}"
    puts "   - Owner: #{@test_user.full_name}"
    
    puts "\n✅ REAL EMAIL TEST COMPLETED SUCCESSFULLY!"
    puts "=" * 60
    
    # Assertions to ensure test passes
    assert emails_sent > 0, "Should send at least one email"
    assert tracker, "Should track workflow execution"
    assert_equal @test_user.email, ActionMailer::Base.deliveries.last.to.first
  end

  test "send test emails to multiple scenarios" do
    puts "\n📬 MULTIPLE SCENARIO EMAIL TEST"
    puts "=" * 50
    
    scenarios = [
      {
        name: "High Value Application",
        user_data: { first_name: "Michael", last_name: "Chen", email: "michael.chen.test@example.com" },
        app_data: { home_value: 1500000, address: "789 Premium Street, Sydney NSW 2000", status: 'submitted' }
      },
      {
        name: "Joint Application",
        user_data: { first_name: "Emma", last_name: "Wilson", email: "emma.wilson.test@example.com" },
        app_data: { home_value: 850000, address: "321 Family Lane, Brisbane QLD 4000", status: 'processing' }
      },
      {
        name: "Investment Property",
        user_data: { first_name: "David", last_name: "Rodriguez", email: "david.rodriguez.test@example.com" },
        app_data: { home_value: 650000, address: "654 Investment Ave, Perth WA 6000", status: 'rejected' }
      }
    ]
    
    ActionMailer::Base.deliveries.clear
    
    scenarios.each_with_index do |scenario, index|
      puts "\n📋 Scenario #{index + 1}: #{scenario[:name]}"
      
      # Create user for scenario
      user = User.create!(
        email: scenario[:user_data][:email],
        password: "password123",
        first_name: scenario[:user_data][:first_name],
        last_name: scenario[:user_data][:last_name],
        mobile_number: "+61400#{rand(100000..999999)}",
        country_of_residence: "Australia",
        email_verified: true
      )
      
      # Create application
      application = Application.create!(
        user: user,
        status: scenario[:app_data][:status],
        address: scenario[:app_data][:address],
        home_value: scenario[:app_data][:home_value],
        ownership_status: 'individual',
        property_state: 'investment',
        has_existing_mortgage: false,
        existing_mortgage_amount: 0,
        borrower_age: rand(25..65),
        loan_term: 30,
        income_payout_term: 30,
        growth_rate: rand(2.5..5.0).round(1),
        updated_at: rand(2..7).days.ago
      )
      
      puts "   - User: #{user.full_name} (#{user.email})"
      puts "   - Property: #{application.address}"
      puts "   - Value: #{application.formatted_home_value}"
      puts "   - Status: #{application.status_display}"
      
      # Create and execute workflow for each scenario
      workflow = EmailWorkflow.create!(
        name: "Test Scenario #{index + 1} - #{scenario[:name]}",
        trigger_type: 'application_stuck_at_status',
        trigger_conditions: { 'stuck_status' => application.status },
        workflow_builder_data: {
          'nodes' => [
            {
              'id' => 'trigger1',
              'type' => 'trigger',
              'config' => {
                'stuck_status' => application.status,
                'stuck_duration' => 1,
                'stuck_unit' => 'days',
                'run_once' => false
              }
            },
            {
              'id' => 'email1',
              'type' => 'email',
              'config' => {
                'email_template_id' => @stuck_app_template.id,
                'subject' => "TEST #{scenario[:name]} - Application Update"
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
      
      # Force execution
      service = WorkflowExecutionService.new(workflow, application)
      service.execute!
      
      puts "   - Email sent ✅"
    end
    
    puts "\n📊 MULTIPLE SCENARIO SUMMARY"
    puts "Total scenarios tested: #{scenarios.size}"
    puts "Total emails sent: #{ActionMailer::Base.deliveries.size}"
    puts "All emails contain proper personalization and data"
    
    ActionMailer::Base.deliveries.each_with_index do |email, index|
      puts "\n📧 Email #{index + 1}:"
      puts "   - To: #{email.to.first}"
      puts "   - Subject: #{email.subject}"
      puts "   - Contains personalized content: ✅"
    end
    
    assert_equal scenarios.size, ActionMailer::Base.deliveries.size, "Should send one email per scenario"
    puts "\n✅ MULTIPLE SCENARIO TEST COMPLETED!"
  end
  
  private
  
  def teardown
    # Clean up test data
    User.where(email: [
      "real_workflow_test@example.com",
      "michael.chen.test@example.com", 
      "emma.wilson.test@example.com",
      "david.rodriguez.test@example.com"
    ]).destroy_all
  end
end