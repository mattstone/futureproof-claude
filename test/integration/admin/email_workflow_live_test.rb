require "test_helper"

# This test actually sends emails to verify the complete workflow functionality
# Run with: rails test test/integration/admin/email_workflow_live_test.rb
class Admin::EmailWorkflowLiveTest < ActionDispatch::IntegrationTest
  def setup
    # Create test lender and admin user
    @lender = Lender.create!(
      name: "FutureProof Test Lender",
      lender_type: "lender",
      contact_email: "admin@futureproof.com",
      country: "US"
    )
    
    @admin_user = User.create!(
      email: "admin@futureproof.com",
      password: "password123",
      first_name: "Admin",
      last_name: "Tester",
      lender: @lender,
      country_of_residence: "US", 
      terms_accepted: "1",
      admin: true
    )
    
    # Create test user who will receive emails
    @test_user = User.create!(
      email: "test.recipient@futureproof.com", # Change this to your actual email to see emails
      password: "password123",
      first_name: "John",
      last_name: "TestUser",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1"
    )
    
    # Create comprehensive email templates for testing
    create_test_templates
  end
  
  # This test creates and executes a complete onboarding workflow
  test "complete onboarding workflow with real email delivery" do
    puts "\n=== Testing Complete Onboarding Workflow ==="
    
    # Create onboarding workflow
    onboarding_workflow = EmailWorkflow.create!(
      name: "Live Test - User Onboarding Sequence",
      description: "Complete onboarding workflow for new users",
      trigger_type: "user_registered",
      trigger_conditions: { "user_type" => "new" },
      active: true,
      created_by: @admin_user
    )
    
    # Step 1: Immediate welcome email
    step1 = onboarding_workflow.workflow_steps.create!(
      step_type: "send_email",
      name: "Welcome Email",
      position: 1,
      configuration: {
        "email_template_id" => @welcome_template.id,
        "subject" => "🎉 Welcome to FutureProof, #{@test_user.first_name}!",
        "from_email" => "welcome@futureproof.com",
        "from_name" => "FutureProof Team"
      }
    )
    
    # Step 2: Short delay for testing
    step2 = onboarding_workflow.workflow_steps.create!(
      step_type: "delay", 
      name: "Wait 30 seconds",
      position: 2,
      configuration: {
        "duration" => "30",
        "unit" => "seconds"
      }
    )
    
    # Step 3: Getting started email
    step3 = onboarding_workflow.workflow_steps.create!(
      step_type: "send_email",
      name: "Getting Started Guide",
      position: 3,
      configuration: {
        "email_template_id" => @guide_template.id,
        "subject" => "📚 Your FutureProof Getting Started Guide",
        "from_email" => "support@futureproof.com",
        "from_name" => "FutureProof Support"
      }
    )
    
    puts "Created workflow: #{onboarding_workflow.name}"
    puts "Steps: #{onboarding_workflow.workflow_steps.count}"
    
    # Execute the workflow
    execution = onboarding_workflow.execute_for(@test_user)
    
    assert_not_nil execution
    puts "Created execution: #{execution.id}"
    
    # Start the workflow execution
    travel_to Time.current do
      execution.update!(status: 'running', started_at: Time.current)
      
      puts "Started execution at: #{execution.started_at}"
      
      # Execute steps
      while execution.current_step && execution.current_step_position <= onboarding_workflow.workflow_steps.count
        current_step = execution.current_step
        puts "\nExecuting step #{current_step.position}: #{current_step.name}"
        
        # Execute the step
        result = current_step.execute_for(execution)
        
        if result[:success]
          puts "✅ Step completed: #{result[:message]}"
          
          # Move to next step
          execution.current_step_position += 1
          execution.save!
        else
          puts "❌ Step failed: #{result[:error]}"
          execution.update!(status: 'failed')
          break
        end
      end
      
      # Complete execution if all steps done
      if execution.current_step_position > onboarding_workflow.workflow_steps.count
        execution.update!(status: 'completed', completed_at: Time.current)
      end
      
      execution.reload
      puts "\nExecution final status: #{execution.status}"
      puts "Progress: #{execution.progress_percentage}%"
      
      # Verify emails were sent
      emails_sent = ActionMailer::Base.deliveries.select { |email| 
        email.to.include?(@test_user.email) 
      }
      
      puts "\n📧 Emails sent: #{emails_sent.count}"
      emails_sent.each_with_index do |email, index|
        puts "  #{index + 1}. Subject: #{email.subject}"
        puts "     To: #{email.to.join(', ')}"
        puts "     From: #{email.from.join(', ')}"
      end
      
      # Assertions
      assert_equal "completed", execution.status
      assert emails_sent.count >= 1, "Should have sent at least 1 email"
    end
  end
  
  private
  
  def create_test_templates
    @welcome_template = EmailTemplate.create!(
      name: "Live Test Welcome Email",
      subject: "Welcome to FutureProof!",
      content: """
        <h1>Welcome to FutureProof, {{user.first_name}}!</h1>
        <p>We're thrilled to have you join our platform.</p>
        <p>Your email: {{user.email}}</p>
        <p>Get ready to secure your financial future!</p>
        <hr>
        <small>This is a test email from the workflow system.</small>
      """,
      content_body: """
        <h1>Welcome to FutureProof, {{user.first_name}}!</h1>
        <p>We're thrilled to have you join our platform.</p>
        <p>Your email: {{user.email}}</p>
        <p>Get ready to secure your financial future!</p>
        <hr>
        <small>This is a test email from the workflow system.</small>
      """,
      email_category: "operational",
      template_type: "verification"
    )
    
    @guide_template = EmailTemplate.create!(
      name: "Getting Started Guide",
      subject: "Your Getting Started Guide",
      content: """
        <h2>Getting Started with FutureProof</h2>
        <p>Hi {{user.first_name}},</p>
        <p>Here's everything you need to know to get started:</p>
        <ol>
          <li>Complete your profile</li>
          <li>Upload required documents</li>
          <li>Schedule your consultation</li>
        </ol>
        <p>Questions? Reply to this email!</p>
      """,
      content_body: """
        <h2>Getting Started with FutureProof</h2>
        <p>Hi {{user.first_name}},</p>
        <p>Here's everything you need to know to get started:</p>
        <ol>
          <li>Complete your profile</li>
          <li>Upload required documents</li>
          <li>Schedule your consultation</li>
        </ol>
        <p>Questions? Reply to this email!</p>
      """,
      email_category: "operational",
      template_type: "verification"
    )
  end
end