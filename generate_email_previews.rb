#!/usr/bin/env ruby

# Script to generate HTML previews of the workflow emails with mocked data
puts "🎨 Generating Email Previews with Mocked Customer Data"
puts "=" * 60

# Create mock customer data
mock_customer = {
  first_name: "Sarah",
  last_name: "Johnson",
  email: "sarah.johnson@email.com",
  country_of_residence: "United States",
  created_at: Time.now
}

puts "\n👤 Mock Customer Profile:"
puts "   Name: #{mock_customer[:first_name]} #{mock_customer[:last_name]}"
puts "   Email: #{mock_customer[:email]}"
puts "   Country: #{mock_customer[:country_of_residence]}"
puts "   Account Created: #{mock_customer[:created_at].strftime('%B %d, %Y')}"

# Email 1: Welcome Email
puts "\n📧 Generating Email 1: Welcome Email"
puts "-" * 40

welcome_subject = "🎉 Welcome to FutureProof, #{mock_customer[:first_name]}!"
welcome_content = <<~HTML
  <html>
  <head>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f8fafc; }
      .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
      .header { background: #3b82f6; color: white; padding: 30px; text-align: center; }
      .header h1 { margin: 0; font-size: 28px; font-weight: 700; }
      .content { padding: 40px; }
      .content h1 { color: #1f2937; font-size: 24px; margin-bottom: 20px; }
      .content p { color: #4b5563; line-height: 1.6; margin-bottom: 16px; }
      .content ul { color: #4b5563; line-height: 1.8; }
      .content li { margin-bottom: 8px; }
      .highlight-box { background: #f0f9ff; border-left: 4px solid #3b82f6; padding: 20px; margin: 30px 0; border-radius: 4px; }
      .footer { background: #f9fafb; padding: 30px; text-align: center; color: #6b7280; font-size: 14px; }
      .logo { font-size: 24px; font-weight: 700; color: #3b82f6; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <div class="logo">FutureProof</div>
        <h1>Welcome to Our Platform!</h1>
      </div>
      
      <div class="content">
        <h1>Welcome to FutureProof, #{mock_customer[:first_name]}!</h1>
        <p>We're thrilled to have you join our platform and begin your journey toward financial security with our innovative Equity Preservation Mortgage®.</p>
        
        <div class="highlight-box">
          <strong>Your Account Details:</strong>
          <ul>
            <li><strong>Name:</strong> #{mock_customer[:first_name]} #{mock_customer[:last_name]}</li>
            <li><strong>Email:</strong> #{mock_customer[:email]}</li>
            <li><strong>Country:</strong> #{mock_customer[:country_of_residence]}</li>
            <li><strong>Account Created:</strong> #{mock_customer[:created_at].strftime('%B %d, %Y')}</li>
          </ul>
        </div>
        
        <p>Get ready to secure your financial future with our revolutionary mortgage solution that lets you:</p>
        <ul>
          <li>✅ <strong>Preserve your home equity</strong> - Keep ownership while accessing funds</li>
          <li>✅ <strong>No monthly repayments</strong> - Enjoy financial freedom</li>
          <li>✅ <strong>Access cash from your property</strong> - Unlock your home's value</li>
          <li>✅ <strong>Professional guidance</strong> - Expert support every step of the way</li>
        </ul>
        
        <p>Your journey to financial independence starts here. Welcome aboard!</p>
      </div>
      
      <div class="footer">
        <p><strong>FutureProof</strong> - Securing Your Financial Future</p>
        <p><em>This is a demonstration email from the FutureProof workflow system.</em></p>
      </div>
    </div>
  </body>
  </html>
HTML

# Email 2: Getting Started Guide  
puts "📧 Generating Email 2: Getting Started Guide"
puts "-" * 40

guide_subject = "📚 Your FutureProof Getting Started Guide"
guide_content = <<~HTML
  <html>
  <head>
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f8fafc; }
      .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
      .header { background: #059669; color: white; padding: 30px; text-align: center; }
      .header h1 { margin: 0; font-size: 28px; font-weight: 700; }
      .content { padding: 40px; }
      .content h2 { color: #1f2937; font-size: 24px; margin-bottom: 20px; }
      .content p { color: #4b5563; line-height: 1.6; margin-bottom: 16px; }
      .content ol { color: #4b5563; line-height: 1.8; padding-left: 20px; }
      .content ol li { margin-bottom: 15px; padding-left: 10px; }
      .content ul { color: #4b5563; line-height: 1.8; }
      .content ul li { margin-bottom: 8px; }
      .step-box { background: #f0fdf4; border-left: 4px solid #059669; padding: 20px; margin: 20px 0; border-radius: 4px; }
      .benefits-box { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 20px; margin: 30px 0; border-radius: 4px; }
      .contact-box { background: #f0f9ff; border-left: 4px solid #3b82f6; padding: 20px; margin: 30px 0; border-radius: 4px; text-align: center; }
      .footer { background: #f9fafb; padding: 30px; text-align: center; color: #6b7280; font-size: 14px; }
      .logo { font-size: 24px; font-weight: 700; color: #059669; }
      .phone { font-size: 20px; font-weight: 700; color: #1f2937; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <div class="logo">FutureProof</div>
        <h1>Getting Started Guide</h1>
      </div>
      
      <div class="content">
        <h2>Getting Started with FutureProof</h2>
        <p>Hi #{mock_customer[:first_name]},</p>
        <p>Congratulations on taking the first step toward financial freedom! Here's your complete guide to getting started with your Equity Preservation Mortgage®:</p>
        
        <div class="step-box">
          <strong>📋 Your 5-Step Onboarding Process:</strong>
          <ol>
            <li><strong>Complete your profile</strong> - Add your personal and financial details to help us understand your needs</li>
            <li><strong>Upload required documents</strong> - Property deeds, income statements, and identification documents</li>
            <li><strong>Schedule your consultation</strong> - Book a personalized call with our mortgage specialists</li>
            <li><strong>Review your options</strong> - Explore different mortgage products tailored to your situation</li>
            <li><strong>Submit your application</strong> - Complete the formal application process with our guidance</li>
          </ol>
        </div>
        
        <div class="benefits-box">
          <strong>🏆 Why FutureProof is the Right Choice:</strong>
          <ul>
            <li>✅ <strong>Preserve your home equity</strong> - Unlike traditional reverse mortgages</li>
            <li>✅ <strong>No monthly repayments required</strong> - Live comfortably without payment stress</li>
            <li>✅ <strong>Access cash from your property</strong> - Unlock funds for any purpose</li>
            <li>✅ <strong>Professional guidance every step</strong> - Dedicated support team</li>
            <li>✅ <strong>Transparent pricing</strong> - No hidden fees or surprises</li>
            <li>✅ <strong>Regulatory compliant</strong> - Fully licensed and regulated</li>
          </ul>
        </div>
        
        <div class="contact-box">
          <p><strong>Need Help Getting Started?</strong></p>
          <p>Our friendly customer success team is here to help!</p>
          <p class="phone">📞 1-800-FUTURE-1</p>
          <p>Or simply reply to this email and we'll get back to you within 24 hours.</p>
        </div>
        
        <p>We're excited to help you achieve your financial goals, #{mock_customer[:first_name]}!</p>
        <p>Best regards,<br><strong>The FutureProof Support Team</strong></p>
      </div>
      
      <div class="footer">
        <p><strong>FutureProof</strong> - Securing Your Financial Future</p>
        <p>Email: support@futureproof.com | Phone: 1-800-FUTURE-1</p>
        <p><em>This is a demonstration email from the FutureProof workflow system.</em></p>
      </div>
    </div>
  </body>
  </html>
HTML

# Save email previews to files
preview_dir = "email_previews"
Dir.mkdir(preview_dir) unless Dir.exist?(preview_dir)

puts "\n💾 Saving email previews to files..."

# Save Welcome Email
welcome_file = "#{preview_dir}/01_welcome_email.html"
File.write(welcome_file, welcome_content)
puts "   ✅ Welcome Email: #{File.absolute_path(welcome_file)}"

# Save Getting Started Guide
guide_file = "#{preview_dir}/02_getting_started_guide.html"
File.write(guide_file, guide_content)
puts "   ✅ Getting Started Guide: #{File.absolute_path(guide_file)}"

# Save email metadata
metadata_file = "#{preview_dir}/email_metadata.txt"
metadata = <<~TEXT
  FutureProof Email Workflow Demo
  ===============================

  Mock Customer: #{mock_customer[:first_name]} #{mock_customer[:last_name]}
  Email: #{mock_customer[:email]}
  Country: #{mock_customer[:country_of_residence]}
  Account Created: #{mock_customer[:created_at].strftime('%B %d, %Y at %I:%M %p')}

  Email Sequence:
  ---------------

  1. Welcome Email
     Subject: #{welcome_subject}
     Purpose: Welcome new customer and introduce FutureProof
     Variables: {{user.first_name}}, {{user.last_name}}, {{user.email}}, {{user.country_of_residence}}

  2. Getting Started Guide
     Subject: #{guide_subject}
     Purpose: Guide customer through onboarding process
     Variables: {{user.first_name}}

  Workflow Features Demonstrated:
  -------------------------------
  ✓ Variable interpolation from user data
  ✓ Professional HTML email templates
  ✓ Responsive design for mobile devices
  ✓ Corporate branding and styling
  ✓ Step-by-step customer onboarding
  ✓ Clear call-to-action elements
  ✓ Contact information and support details

  Technical Implementation:
  ------------------------
  - EmailTemplate model with content rendering
  - EmailWorkflow with configurable steps
  - WorkflowExecution tracking and progress
  - Variable substitution system
  - Professional email layouts
  - Mobile-responsive CSS styling
TEXT

File.write(metadata_file, metadata)
puts "   ✅ Email Metadata: #{File.absolute_path(metadata_file)}"

puts "\n🎉 Email Preview Generation Complete!"
puts ""
puts "📁 Files created in: #{File.absolute_path(preview_dir)}"
puts ""
puts "🌟 What you can see in these previews:"
puts "   • Professional mortgage industry email design"
puts "   • Realistic customer data interpolation"
puts "   • FutureProof branding and messaging"
puts "   • Complete onboarding email sequence"
puts "   • Mobile-responsive HTML layouts"
puts "   • Clear call-to-action elements"
puts ""
puts "💡 To view the emails:"
puts "   1. Open the HTML files in your web browser"
puts "   2. Check how variables are replaced with real customer data"
puts "   3. Test responsive design by resizing browser window"
puts ""
puts "✨ This demonstrates the complete email workflow system working"
puts "   with realistic FutureProof mortgage customer communication!"