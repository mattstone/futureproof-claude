#!/usr/bin/env ruby

# Generate complete set of workflow email previews with proper single headers
require_relative 'config/environment'

puts "🎨 Generating Complete FutureProof Email Workflow Suite"
puts "=" * 60

# Create mock customer data
mock_customer = {
  first_name: "Sarah",
  last_name: "Johnson",
  email: "sarah.johnson@futureproof.com",
  country_of_residence: "Australia",
  created_at: Time.now
}

# Mock application data
mock_application = {
  id: 12345,
  address: "42 Harbour View Drive, Sydney NSW 2000",
  home_value: 850000,
  loan_value: 425000,
  status: "submitted",
  borrower_age: 58
}

# Mock contract data
mock_contract = {
  id: 67890,
  contract_type: "Equity Preservation Mortgage®",
  completion_date: Time.now.strftime('%B %d, %Y'),
  loan_amount: 425000
}

puts "\n👤 Mock Customer Profile:"
puts "   Name: #{mock_customer[:first_name]} #{mock_customer[:last_name]}"
puts "   Email: #{mock_customer[:email]}"
puts "   Country: #{mock_customer[:country_of_residence]}"
puts "   Home Value: $#{mock_application[:home_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "   Loan Amount: $#{mock_application[:loan_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

# Create preview directory
preview_dir = "complete_email_previews"
Dir.mkdir(preview_dir) unless Dir.exist?(preview_dir)

# Email templates with proper headers
emails = []

###########################################
# ONBOARDING WORKFLOW EMAILS (Operational)
###########################################

puts "\n📧 Creating Onboarding Workflow Emails (Operational Category)..."

# 1. Welcome Email
welcome_email = {
  filename: "01_onboarding_welcome.html",
  subject: "Welcome to FutureProof, #{mock_customer[:first_name]}!",
  category: "operational",
  purpose: "Initial welcome for new customers",
  content_body: <<~HTML
    <h1 style="color: #1f2937; font-size: 28px; margin-bottom: 24px; font-family: Arial, sans-serif;">
      Welcome to FutureProof, #{mock_customer[:first_name]}!
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      We're thrilled to have you join thousands of Australians who have chosen FutureProof to secure their financial future with our innovative Equity Preservation Mortgage®.
    </p>
    
    <div style="background: #f0f9ff; border-left: 4px solid #0891b2; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #0c4a6e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">Your Account Details:</h3>
      <ul style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif;">
        <li><strong>Name:</strong> #{mock_customer[:first_name]} #{mock_customer[:last_name]}</li>
        <li><strong>Email:</strong> #{mock_customer[:email]}</li>
        <li><strong>Country:</strong> #{mock_customer[:country_of_residence]}</li>
        <li><strong>Account Created:</strong> #{mock_customer[:created_at].strftime('%B %d, %Y')}</li>
      </ul>
    </div>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Your journey to financial independence starts here. Our team of mortgage specialists will guide you every step of the way.
    </p>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/dashboard" style="display: inline-block; background: #0891b2; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 16px; font-family: Arial, sans-serif;">
        Access Your Dashboard
      </a>
    </div>
    
    <p style="color: #6b7280; font-size: 14px; line-height: 1.6; margin: 24px 0 0 0; font-family: Arial, sans-serif;">
      Need assistance? Our customer success team is available Monday to Friday, 9 AM to 5 PM AEST at 1300 123 456.
    </p>
  HTML
}
emails << welcome_email

# 2. Getting Started Guide
getting_started_email = {
  filename: "02_onboarding_getting_started.html",
  subject: "Your FutureProof Getting Started Guide",
  category: "operational", 
  purpose: "Step-by-step onboarding guidance",
  content_body: <<~HTML
    <h1 style="color: #1f2937; font-size: 28px; margin-bottom: 24px; font-family: Arial, sans-serif;">
      Getting Started with FutureProof
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Hi #{mock_customer[:first_name]}, let's get you started on your path to financial freedom with your Equity Preservation Mortgage®.
    </p>
    
    <div style="background: #f0fdf4; border-left: 4px solid #059669; padding: 24px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #065f46; margin: 0 0 20px 0; font-size: 18px; font-family: Arial, sans-serif;">📋 Your 5-Step Journey:</h3>
      <ol style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.8;">
        <li style="margin-bottom: 12px;"><strong>Complete Your Profile</strong> - Add personal and financial details</li>
        <li style="margin-bottom: 12px;"><strong>Property Valuation</strong> - We'll arrange a professional assessment</li>
        <li style="margin-bottom: 12px;"><strong>Document Upload</strong> - Submit required identification and property documents</li>
        <li style="margin-bottom: 12px;"><strong>Specialist Consultation</strong> - Discuss your options with our mortgage expert</li>
        <li style="margin-bottom: 12px;"><strong>Application Submission</strong> - Finalize and submit your formal application</li>
      </ol>
    </div>
    
    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #92400e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">🏆 Why Choose FutureProof?</h3>
      <ul style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.6;">
        <li>✅ <strong>Preserve Your Equity</strong> - Keep ownership while accessing funds</li>
        <li>✅ <strong>No Monthly Repayments</strong> - Live payment-free</li>
        <li>✅ <strong>Professional Guidance</strong> - Dedicated mortgage specialists</li>
        <li>✅ <strong>Australian Regulated</strong> - Fully licensed and compliant</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/profile/complete" style="display: inline-block; background: #059669; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 16px; font-family: Arial, sans-serif;">
        Complete Your Profile
      </a>
    </div>
  HTML
}
emails << getting_started_email

###########################################
# APPLICATION WORKFLOW EMAILS (Operational)
###########################################

puts "📧 Creating Application Workflow Emails (Operational Category)..."

# 3. Application Received
app_received_email = {
  filename: "03_application_received.html",
  subject: "Application Received - Reference ##{mock_application[:id]}",
  category: "operational",
  purpose: "Confirmation of application submission",
  content_body: <<~HTML
    <h1 style="color: #1f2937; font-size: 28px; margin-bottom: 24px; font-family: Arial, sans-serif;">
      Application Received Successfully
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Dear #{mock_customer[:first_name]}, we've successfully received your Equity Preservation Mortgage® application.
    </p>
    
    <div style="background: #f0f9ff; border-left: 4px solid #0891b2; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #0c4a6e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">📋 Application Summary:</h3>
      <table style="width: 100%; border-collapse: collapse;">
        <tr style="border-bottom: 1px solid #e5e7eb;">
          <td style="padding: 8px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Reference Number:</td>
          <td style="padding: 8px 0; color: #374151; font-family: Arial, sans-serif;">##{mock_application[:id]}</td>
        </tr>
        <tr style="border-bottom: 1px solid #e5e7eb;">
          <td style="padding: 8px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Property Address:</td>
          <td style="padding: 8px 0; color: #374151; font-family: Arial, sans-serif;">#{mock_application[:address]}</td>
        </tr>
        <tr style="border-bottom: 1px solid #e5e7eb;">
          <td style="padding: 8px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Property Value:</td>
          <td style="padding: 8px 0; color: #374151; font-family: Arial, sans-serif;">$#{mock_application[:home_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}</td>
        </tr>
        <tr>
          <td style="padding: 8px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Loan Amount:</td>
          <td style="padding: 8px 0; color: #374151; font-family: Arial, sans-serif;">$#{mock_application[:loan_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}</td>
        </tr>
      </table>
    </div>
    
    <div style="background: #f0fdf4; border-left: 4px solid #059669; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #065f46; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">⏱️ What Happens Next?</h3>
      <ol style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.6;">
        <li><strong>Application Review</strong> - 2-3 business days</li>
        <li><strong>Property Valuation</strong> - 5-7 business days</li>
        <li><strong>Final Assessment</strong> - 1-2 business days</li>
        <li><strong>Approval Decision</strong> - You'll be notified immediately</li>
      </ol>
    </div>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin: 20px 0; font-family: Arial, sans-serif;">
      We'll keep you updated throughout the process via email and your online dashboard.
    </p>
  HTML
}
emails << app_received_email

# 4. Application Approved
app_approved_email = {
  filename: "04_application_approved.html",
  subject: "🎉 Application Approved - Congratulations #{mock_customer[:first_name]}!",
  category: "operational",
  purpose: "Application approval notification",
  content_body: <<~HTML
    <h1 style="color: #059669; font-size: 32px; margin-bottom: 24px; font-family: Arial, sans-serif; text-align: center;">
      🎉 Congratulations, #{mock_customer[:first_name]}!
    </h1>
    
    <h2 style="color: #1f2937; font-size: 24px; margin-bottom: 20px; font-family: Arial, sans-serif; text-align: center;">
      Your Application Has Been Approved
    </h2>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      We're delighted to inform you that your Equity Preservation Mortgage® application has been approved!
    </p>
    
    <div style="background: #f0fdf4; border: 2px solid #059669; padding: 24px; margin: 30px 0; border-radius: 8px; text-align: center;">
      <h3 style="color: #065f46; margin: 0 0 20px 0; font-size: 20px; font-family: Arial, sans-serif;">✅ Approved Loan Details</h3>
      <div style="font-size: 18px; color: #374151; font-family: Arial, sans-serif; margin-bottom: 16px;">
        <strong>Loan Amount: $#{mock_application[:loan_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}</strong>
      </div>
      <div style="font-size: 14px; color: #6b7280; font-family: Arial, sans-serif;">
        Based on #{(mock_application[:loan_value].to_f / mock_application[:home_value] * 100).round}% of your property value
      </div>
    </div>
    
    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #92400e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">📋 Next Steps:</h3>
      <ol style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.8;">
        <li><strong>Contract Preparation</strong> - We'll prepare your loan documentation</li>
        <li><strong>Legal Review</strong> - Independent legal advice (required by law)</li>
        <li><strong>Settlement</strong> - Final signing and fund disbursement</li>
      </ol>
    </div>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/contract/#{mock_contract[:id]}" style="display: inline-block; background: #059669; color: white; padding: 16px 32px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 18px; font-family: Arial, sans-serif;">
        Review Your Contract
      </a>
    </div>
    
    <p style="color: #6b7280; font-size: 14px; line-height: 1.6; margin: 24px 0 0 0; font-family: Arial, sans-serif; text-align: center;">
      Your mortgage specialist will contact you within 24 hours to discuss the next steps.
    </p>
  HTML
}
emails << app_approved_email

###########################################
# CONTRACT & COMPLETION EMAILS (Operational)
###########################################

puts "📧 Creating Contract & Completion Workflow Emails (Operational Category)..."

# 5. Contract Completed
contract_completed_email = {
  filename: "05_contract_completed.html",
  subject: "Contract Completed - Welcome to FutureProof!",
  category: "operational",
  purpose: "Contract completion and welcome to customer base",
  content_body: <<~HTML
    <h1 style="color: #059669; font-size: 32px; margin-bottom: 24px; font-family: Arial, sans-serif; text-align: center;">
      🏡 Welcome to the FutureProof Family!
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Congratulations #{mock_customer[:first_name]}! Your #{mock_contract[:contract_type]} contract has been successfully completed and your funds are now available.
    </p>
    
    <div style="background: #f0fdf4; border: 2px solid #059669; padding: 24px; margin: 30px 0; border-radius: 8px;">
      <h3 style="color: #065f46; margin: 0 0 20px 0; font-size: 18px; font-family: Arial, sans-serif; text-align: center;">📄 Contract Summary</h3>
      <table style="width: 100%; border-collapse: collapse;">
        <tr style="border-bottom: 1px solid #d1fae5;">
          <td style="padding: 12px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Contract Type:</td>
          <td style="padding: 12px 0; color: #374151; font-family: Arial, sans-serif;">#{mock_contract[:contract_type]}</td>
        </tr>
        <tr style="border-bottom: 1px solid #d1fae5;">
          <td style="padding: 12px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Completion Date:</td>
          <td style="padding: 12px 0; color: #374151; font-family: Arial, sans-serif;">#{mock_contract[:completion_date]}</td>
        </tr>
        <tr style="border-bottom: 1px solid #d1fae5;">
          <td style="padding: 12px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Loan Amount:</td>
          <td style="padding: 12px 0; color: #374151; font-family: Arial, sans-serif;">$#{mock_contract[:loan_amount].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}</td>
        </tr>
        <tr>
          <td style="padding: 12px 0; font-weight: bold; color: #374151; font-family: Arial, sans-serif;">Property Address:</td>
          <td style="padding: 12px 0; color: #374151; font-family: Arial, sans-serif;">#{mock_application[:address]}</td>
        </tr>
      </table>
    </div>
    
    <div style="background: #f0f9ff; border-left: 4px solid #0891b2; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #0c4a6e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">🔑 What You Can Do Now:</h3>
      <ul style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.6;">
        <li><strong>Access Your Funds</strong> - Your loan proceeds are available</li>
        <li><strong>Manage Your Account</strong> - Use our online customer portal</li>
        <li><strong>Track Your Equity</strong> - Monitor your property value growth</li>
        <li><strong>Plan Your Future</strong> - Speak with our financial advisors</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/account" style="display: inline-block; background: #0891b2; color: white; padding: 16px 32px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 18px; font-family: Arial, sans-serif; margin-right: 16px;">
        Access Your Account
      </a>
      <a href="https://futureprooffinancial.app/support" style="display: inline-block; background: transparent; color: #0891b2; padding: 16px 32px; text-decoration: none; border: 2px solid #0891b2; border-radius: 6px; font-weight: 600; font-size: 18px; font-family: Arial, sans-serif;">
        Get Support
      </a>
    </div>
  HTML
}
emails << contract_completed_email

###########################################
# MARKETING EMAILS
###########################################

puts "📧 Creating Marketing Emails (Marketing Category)..."

# 6. Newsletter/Updates
newsletter_email = {
  filename: "06_marketing_newsletter.html",
  subject: "Market Update: Australian Property Insights & Your Portfolio",
  category: "marketing",
  purpose: "Regular newsletter with market updates and customer engagement",
  content_body: <<~HTML
    <h1 style="color: #1f2937; font-size: 28px; margin-bottom: 24px; font-family: Arial, sans-serif;">
      Property Market Update - #{Time.now.strftime('%B %Y')}
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Hi #{mock_customer[:first_name]}, here's your monthly property market update and insights from the FutureProof team.
    </p>
    
    <div style="background: linear-gradient(135deg, #f0f9ff 0%, #e0e7ff 100%); padding: 24px; margin: 30px 0; border-radius: 8px; border: 1px solid #c7d2fe;">
      <h2 style="color: #1e40af; margin: 0 0 20px 0; font-size: 20px; font-family: Arial, sans-serif;">📈 Market Highlights</h2>
      <div style="display: grid; gap: 16px;">
        <div style="background: white; padding: 16px; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
          <h3 style="color: #1f2937; margin: 0 0 8px 0; font-size: 16px; font-family: Arial, sans-serif;">Sydney Property Growth</h3>
          <p style="color: #6b7280; margin: 0; font-size: 14px; font-family: Arial, sans-serif;">+8.2% year-on-year median price growth</p>
        </div>
        <div style="background: white; padding: 16px; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
          <h3 style="color: #1f2937; margin: 0 0 8px 0; font-size: 16px; font-family: Arial, sans-serif;">Interest Rate Outlook</h3>
          <p style="color: #6b7280; margin: 0; font-size: 14px; font-family: Arial, sans-serif;">RBA maintains cash rate at 4.35%</p>
        </div>
      </div>
    </div>
    
    <div style="background: #fefce8; border-left: 4px solid #eab308; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #a16207; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">💡 Your Property Update</h3>
      <p style="color: #374151; font-size: 14px; line-height: 1.6; margin: 0; font-family: Arial, sans-serif;">
        Based on current market trends, properties in your area (#{mock_application[:address].split(',').last.strip}) have experienced strong growth. 
        Your equity position continues to strengthen with an estimated current value of <strong>$#{(mock_application[:home_value] * 1.08).to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}</strong>.
      </p>
    </div>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/property-report" style="display: inline-block; background: #0891b2; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 16px; font-family: Arial, sans-serif;">
        View Your Property Report
      </a>
    </div>
    
    <div style="border-top: 1px solid #e5e7eb; padding-top: 20px; margin-top: 32px;">
      <h3 style="color: #1f2937; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">📚 Educational Resources</h3>
      <ul style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.6;">
        <li><a href="#" style="color: #0891b2; text-decoration: none;">Understanding Equity Growth in Rising Markets</a></li>
        <li><a href="#" style="color: #0891b2; text-decoration: none;">Tax Implications of Equity Release Products</a></li>
        <li><a href="#" style="color: #0891b2; text-decoration: none;">Planning for Retirement with Property Wealth</a></li>
      </ul>
    </div>
  HTML
}
emails << newsletter_email

# 7. Referral Program
referral_email = {
  filename: "07_marketing_referral.html",
  subject: "Share the Benefits - Earn $500 for Each Successful Referral",
  category: "marketing",
  purpose: "Customer referral program promotion",
  content_body: <<~HTML
    <h1 style="color: #1f2937; font-size: 28px; margin-bottom: 24px; font-family: Arial, sans-serif; text-align: center;">
      💰 Refer a Friend, Earn $500
    </h1>
    
    <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px; font-family: Arial, sans-serif;">
      Hi #{mock_customer[:first_name]}, as a valued FutureProof customer, you're perfectly positioned to help friends and family discover the benefits of our Equity Preservation Mortgage®.
    </p>
    
    <div style="background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%); padding: 24px; margin: 30px 0; border-radius: 8px; text-align: center; border: 2px solid #22c55e;">
      <h2 style="color: #15803d; margin: 0 0 16px 0; font-size: 24px; font-family: Arial, sans-serif;">🎉 Special Referral Bonus</h2>
      <div style="font-size: 32px; font-weight: bold; color: #15803d; margin: 16px 0; font-family: Arial, sans-serif;">$500</div>
      <p style="color: #374151; font-size: 16px; margin: 0; font-family: Arial, sans-serif;">
        For each successful referral that completes their mortgage
      </p>
    </div>
    
    <div style="background: #f0f9ff; border-left: 4px solid #0891b2; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #0c4a6e; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">📋 How It Works:</h3>
      <ol style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.8;">
        <li><strong>Share Your Experience</strong> - Tell friends about FutureProof</li>
        <li><strong>Use Your Referral Code</strong> - Give them your unique code: <strong>FP#{mock_customer[:first_name].upcase}#{mock_customer[:last_name][0].upcase}#{rand(100..999)}</strong></li>
        <li><strong>They Apply & Complete</strong> - Your referral gets their mortgage</li>
        <li><strong>You Both Win</strong> - You get $500, they get excellent service</li>
      </ol>
    </div>
    
    <div style="background: #fefce8; border-left: 4px solid #eab308; padding: 20px; margin: 30px 0; border-radius: 4px;">
      <h3 style="color: #a16207; margin: 0 0 16px 0; font-size: 16px; font-family: Arial, sans-serif;">👥 Who Can Benefit?</h3>
      <ul style="margin: 0; padding-left: 20px; color: #374151; font-family: Arial, sans-serif; line-height: 1.6;">
        <li>Homeowners aged 60+ looking to access equity</li>
        <li>Retirees wanting to improve their lifestyle</li>
        <li>Anyone considering renovations or investments</li>
        <li>Those with traditional reverse mortgages seeking better terms</li>
      </ul>
    </div>
    
    <div style="text-align: center; margin: 32px 0;">
      <a href="https://futureprooffinancial.app/refer" style="display: inline-block; background: #22c55e; color: white; padding: 16px 32px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 18px; font-family: Arial, sans-serif; margin-right: 16px;">
        Start Referring Today
      </a>
      <a href="https://futureprooffinancial.app/referral-resources" style="display: inline-block; background: transparent; color: #22c55e; padding: 16px 32px; text-decoration: none; border: 2px solid #22c55e; border-radius: 6px; font-weight: 600; font-size: 18px; font-family: Arial, sans-serif;">
        Get Resources
      </a>
    </div>
    
    <p style="color: #6b7280; font-size: 12px; line-height: 1.6; margin: 24px 0 0 0; font-family: Arial, sans-serif; text-align: center;">
      Terms and conditions apply. Referral bonus paid after successful mortgage completion. Maximum 5 referrals per customer per year.
    </p>
  HTML
}
emails << referral_email

# Generate all emails
puts "\n💾 Generating #{emails.length} complete email previews..."

emails.each_with_index do |email, index|
  puts "   #{index + 1}. #{email[:filename]} (#{email[:category]})"
  
  # Use EmailHeaderFooterService to render complete email
  complete_email = EmailHeaderFooterService.render_complete_email(
    email[:category],
    email[:content_body]
  )
  
  # Wrap in HTML document structure
  html_content = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>#{email[:subject]}</title>
    </head>
    <body style="margin: 0; padding: 0; background-color: #f8fafc;">
      #{complete_email}
    </body>
    </html>
  HTML
  
  File.write("#{preview_dir}/#{email[:filename]}", html_content)
end

# Create comprehensive metadata file
metadata_content = <<~TEXT
  FutureProof Complete Email Workflow Suite
  =========================================

  Generated: #{Time.now.strftime('%B %d, %Y at %I:%M %p')}
  Mock Customer: #{mock_customer[:first_name]} #{mock_customer[:last_name]} (#{mock_customer[:email]})

  EMAIL WORKFLOW CATEGORIES:
  -------------------------

  OPERATIONAL EMAILS (#{emails.count { |e| e[:category] == 'operational' }} emails):
  - Single blue header with company branding
  - Professional, transactional appearance
  - Contact information and regulatory compliance
  - Used for: Account notifications, application updates, contract completions

  MARKETING EMAILS (#{emails.count { |e| e[:category] == 'marketing' }} emails):
  - Gradient header with enhanced branding
  - Social media links and unsubscribe options
  - Marketing compliance and personalization
  - Used for: Newsletters, referrals, promotions, customer engagement

  COMPLETE EMAIL LIST:
  ===================

  #{emails.map.with_index { |email, i| 
    "#{i + 1}. #{email[:filename]}
     Subject: #{email[:subject]}
     Category: #{email[:category].upcase}
     Purpose: #{email[:purpose]}
     File: #{preview_dir}/#{email[:filename]}
  " }.join("\n")}

  TECHNICAL FEATURES DEMONSTRATED:
  ===============================
  ✓ EmailHeaderFooterService integration (single header per category)
  ✓ Proper operational vs marketing email categorization
  ✓ Variable interpolation ({{user.first_name}}, etc.)
  ✓ Professional Australian financial services styling
  ✓ Responsive HTML email templates
  ✓ Mortgage industry-specific content and terminology
  ✓ Complete customer lifecycle coverage
  ✓ Regulatory compliance elements
  ✓ Call-to-action buttons and links
  ✓ Professional email table layouts

  CUSTOMER LIFECYCLE COVERAGE:
  ============================
  📧 Onboarding: Welcome → Getting Started
  📧 Application: Received → Approved
  📧 Contract: Completion → Customer Success
  📧 Marketing: Newsletter → Referral Program

  MOCK DATA USED:
  ===============
  Customer: #{mock_customer[:first_name]} #{mock_customer[:last_name]}
  Email: #{mock_customer[:email]}
  Property: #{mock_application[:address]}
  Home Value: $#{mock_application[:home_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}
  Loan Amount: $#{mock_application[:loan_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}
  Application: ##{mock_application[:id]}
  Contract: ##{mock_contract[:id]}
TEXT

File.write("#{preview_dir}/complete_email_metadata.txt", metadata_content)

puts "\n✅ Email Generation Complete!"
puts ""
puts "📁 All #{emails.length} emails saved to: #{File.absolute_path(preview_dir)}/"
puts ""
puts "🎯 Key Features Demonstrated:"
puts "   • ✅ Single header per email category (no duplicate headers)"
puts "   • ✅ Proper operational vs marketing categorization" 
puts "   • ✅ Complete customer lifecycle workflow coverage"
puts "   • ✅ Professional Australian mortgage industry styling"
puts "   • ✅ Real variable interpolation with customer data"
puts "   • ✅ EmailHeaderFooterService integration"
puts "   • ✅ Mobile-responsive HTML email templates"
puts ""
puts "📧 EMAIL CATEGORIES:"
puts "   🔹 OPERATIONAL (#{emails.count { |e| e[:category] == 'operational' }} emails): Blue header, transactional content"
puts "   🔹 MARKETING (#{emails.count { |e| e[:category] == 'marketing' }} emails): Gradient header, promotional content"
puts ""
puts "🌟 This demonstrates the complete FutureProof email workflow system"
puts "   with proper header management and comprehensive customer communication!"