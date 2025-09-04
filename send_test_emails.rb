#!/usr/bin/env ruby

# Script to send test emails using the workflow system
puts "🚀 Starting Email Workflow Test Script"
puts "=" * 50

# Create test data
puts "\n📝 Creating test data..."

# Create test lender
lender = Lender.create!(
  name: "FutureProof Demo Lender",
  lender_type: "lender",
  contact_email: "demo@futureproof.com",
  country: "US"
)

# Create admin user
admin_user = User.create!(
  email: "admin@futureproof-demo.com",
  password: "password123",
  first_name: "Demo",
  last_name: "Admin",
  lender: lender,
  country_of_residence: "US",
  terms_accepted: "1",
  admin: true
)

# Create test customer who will receive emails
test_customer = User.create!(
  email: "test.customer@futureproof-demo.com", # Change this to your email
  password: "password123",
  first_name: "John",
  last_name: "Smith",
  lender: lender,
  country_of_residence: "US",
  terms_accepted: "1"
)

puts "✅ Created test lender: #{lender.name}"
puts "✅ Created admin user: #{admin_user.email}"
puts "✅ Created test customer: #{test_customer.email}"

# Create email templates
puts "\n📧 Creating email templates..."

welcome_template = EmailTemplate.create!(
  name: "Demo Welcome Email",
  subject: "Welcome to FutureProof, {{user.first_name}}!",
  content: """
    <h1>Welcome to FutureProof, {{user.first_name}}!</h1>
    <p>We're thrilled to have you join our platform.</p>
    <p><strong>Your Details:</strong></p>
    <ul>
      <li>Name: {{user.first_name}} {{user.last_name}}</li>
      <li>Email: {{user.email}}</li>
      <li>Country: {{user.country_of_residence}}</li>
    </ul>
    <p>Get ready to secure your financial future with our Equity Preservation Mortgage®!</p>
    <hr>
    <p><em>This is a test email from the FutureProof workflow system.</em></p>
  """,
  content_body: """
    <h1>Welcome to FutureProof, {{user.first_name}}!</h1>
    <p>We're thrilled to have you join our platform.</p>
    <p><strong>Your Details:</strong></p>
    <ul>
      <li>Name: {{user.first_name}} {{user.last_name}}</li>
      <li>Email: {{user.email}}</li>
      <li>Country: {{user.country_of_residence}}</li>
    </ul>
    <p>Get ready to secure your financial future with our Equity Preservation Mortgage®!</p>
    <hr>
    <p><em>This is a test email from the FutureProof workflow system.</em></p>
  """,
  email_category: "operational",
  template_type: "verification"
)

guide_template = EmailTemplate.create!(
  name: "Demo Getting Started Guide",
  subject: "Your FutureProof Getting Started Guide",
  content: """
    <h2>Getting Started with FutureProof</h2>
    <p>Hi {{user.first_name}},</p>
    <p>Here's everything you need to know to get started with your Equity Preservation Mortgage®:</p>
    <ol>
      <li><strong>Complete your profile</strong> - Add your personal and financial details</li>
      <li><strong>Upload required documents</strong> - Property deeds, income statements, etc.</li>
      <li><strong>Schedule your consultation</strong> - Book a call with our mortgage specialists</li>
      <li><strong>Review your options</strong> - Explore different mortgage products</li>
      <li><strong>Submit your application</strong> - Complete the formal application process</li>
    </ol>
    <p><strong>Why choose FutureProof?</strong></p>
    <ul>
      <li>✅ Preserve your home equity</li>
      <li>✅ No monthly repayments required</li>
      <li>✅ Access cash from your property</li>
      <li>✅ Professional guidance every step</li>
    </ul>
    <p>Questions? Reply to this email or call our support team at <strong>1-800-FUTURE-1</strong></p>
    <hr>
    <p><em>FutureProof - Securing Your Financial Future</em></p>
  """,
  content_body: """
    <h2>Getting Started with FutureProof</h2>
    <p>Hi {{user.first_name}},</p>
    <p>Here's everything you need to know to get started with your Equity Preservation Mortgage®:</p>
    <ol>
      <li><strong>Complete your profile</strong> - Add your personal and financial details</li>
      <li><strong>Upload required documents</strong> - Property deeds, income statements, etc.</li>
      <li><strong>Schedule your consultation</strong> - Book a call with our mortgage specialists</li>
      <li><strong>Review your options</strong> - Explore different mortgage products</li>
      <li><strong>Submit your application</strong> - Complete the formal application process</li>
    </ol>
    <p><strong>Why choose FutureProof?</strong></p>
    <ul>
      <li>✅ Preserve your home equity</li>
      <li>✅ No monthly repayments required</li>
      <li>✅ Access cash from your property</li>
      <li>✅ Professional guidance every step</li>
    </ul>
    <p>Questions? Reply to this email or call our support team at <strong>1-800-FUTURE-1</strong></p>
    <hr>
    <p><em>FutureProof - Securing Your Financial Future</em></p>
  """,
  email_category: "operational",
  template_type: "verification"
)

puts "✅ Created welcome email template"
puts "✅ Created getting started guide template"

# Create workflow
puts "\n⚡ Creating email workflow..."

onboarding_workflow = EmailWorkflow.create!(
  name: "Demo Customer Onboarding",
  description: "Complete onboarding sequence for new customers",
  trigger_type: "user_registered",
  trigger_conditions: { "user_type" => "new_customer" },
  active: true,
  created_by: admin_user
)

# Add workflow steps
step1 = onboarding_workflow.workflow_steps.create!(
  step_type: "send_email",
  name: "Welcome Email",
  position: 1,
  configuration: {
    "email_template_id" => welcome_template.id,
    "subject" => "🎉 Welcome to FutureProof, {{user.first_name}}!",
    "from_email" => "welcome@futureproof.com",
    "from_name" => "FutureProof Team"
  }
)

step2 = onboarding_workflow.workflow_steps.create!(
  step_type: "send_email",
  name: "Getting Started Guide",
  position: 2,
  configuration: {
    "email_template_id" => guide_template.id,
    "subject" => "📚 Your FutureProof Getting Started Guide",
    "from_email" => "support@futureproof.com",
    "from_name" => "FutureProof Support Team"
  }
)

puts "✅ Created workflow: #{onboarding_workflow.name}"
puts "✅ Added #{onboarding_workflow.workflow_steps.count} workflow steps"

# Execute workflow
puts "\n🔄 Executing workflow..."

execution = onboarding_workflow.execute_for(test_customer)
puts "✅ Created workflow execution: #{execution.id}"

# Start execution
execution.update!(status: 'running', started_at: Time.current)
puts "✅ Started execution at: #{execution.started_at}"

# Execute each step
onboarding_workflow.workflow_steps.ordered.each do |step|
  puts "\n📤 Executing step #{step.position}: #{step.name}"
  
  result = step.execute_for(execution)
  
  if result[:success]
    puts "   ✅ #{result[:message]}"
  else
    puts "   ❌ Failed: #{result[:error]}"
  end
end

# Complete execution
execution.update!(
  status: 'completed',
  completed_at: Time.current,
  current_step_position: onboarding_workflow.workflow_steps.count + 1
)

puts "\n✅ Workflow execution completed!"
puts "📊 Final status: #{execution.status}"
puts "📈 Progress: #{execution.progress_percentage}%"

# Check delivered emails
delivered_emails = ActionMailer::Base.deliveries
puts "\n📬 Email Summary:"
puts "   Total emails sent: #{delivered_emails.count}"

delivered_emails.each_with_index do |email, index|
  puts "   #{index + 1}. To: #{email.to.join(', ')}"
  puts "      Subject: #{email.subject}"
  puts "      From: #{email.from.join(', ')}"
  puts ""
end

if delivered_emails.any?
  puts "🎉 SUCCESS! Test emails have been sent to: #{test_customer.email}"
  puts ""
  puts "📝 To receive emails at your own address:"
  puts "   1. Edit this script and change test_customer email to your email address"
  puts "   2. Run the script again"
  puts ""
  puts "💡 The emails contain realistic mortgage customer data and demonstrate:"
  puts "   • Variable interpolation ({{user.first_name}}, etc.)"
  puts "   • Professional email formatting"
  puts "   • Complete onboarding sequence"
  puts "   • FutureProof branding and messaging"
else
  puts "⚠️  No emails were sent. Check your Rails email configuration."
end

puts "\n" + "=" * 50
puts "✨ Email Workflow Test Complete!"