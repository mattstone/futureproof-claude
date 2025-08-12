#!/usr/bin/env ruby
# Script to populate random rejected reasons for rejected applications
# Usage: bin/rails runner lib/scripts/populate_rejected_reasons.rb

# Define realistic rejected reasons for mortgage applications
REJECTED_REASONS = [
  "Credit score below minimum requirements (minimum 600 required)",
  "Insufficient income to support loan repayments", 
  "Property value outside acceptable range for our lending criteria",
  "Credit history shows multiple missed payments in the last 12 months",
  "Debt-to-income ratio exceeds our maximum threshold of 35%",
  "Property is in a location we do not currently service",
  "Incomplete documentation provided - missing bank statements",
  "Property type not eligible for Equity Preservation Mortgage",
  "Age verification documents do not meet our requirements",
  "Banking history shows irregular income patterns",
  "Property valuation came in significantly lower than expected",
  "Credit check reveals undisclosed existing mortgages",
  "Application incomplete - missing proof of property ownership",
  "Income source does not meet our stability requirements", 
  "Property is subject to existing legal disputes or liens",
  "Banking statements show insufficient funds for ongoing expenses",
  "Credit report shows recent bankruptcy or insolvency",
  "Property condition assessment reveals major structural issues",
  "Age of applicant exceeds maximum eligibility criteria",
  "Joint application missing required co-borrower documentation",
  "Property located in area with declining market values",
  "Income verification documents appear to have been altered",
  "Existing mortgage balance exceeds property equity threshold",
  "Credit check shows high utilization of existing credit facilities",
  "Property zoning restrictions prevent our mortgage product use"
].freeze

def populate_rejected_reasons(force_update: false)
  puts "Finding all rejected applications..."
  rejected_applications = Application.where(status: 'rejected')
  
  puts "Found #{rejected_applications.count} rejected applications"
  
  if rejected_applications.empty?
    puts "No rejected applications found. Nothing to update."
    return
  end

  # Filter to only update applications without rejected reasons unless force_update is true
  applications_to_update = if force_update
                            rejected_applications
                          else
                            rejected_applications.where(rejected_reason: [nil, ''])
                          end

  if applications_to_update.empty? && !force_update
    puts "All rejected applications already have rejected reasons."
    puts "Use force_update: true to update all applications regardless."
    return
  end

  puts "Updating #{applications_to_update.count} applications..."
  
  updated_count = 0
  applications_to_update.find_each do |application|
    # Select a random reason
    new_reason = REJECTED_REASONS.sample
    
    # Update the application
    old_reason = application.rejected_reason
    application.rejected_reason = new_reason
    
    if application.save
      puts "✓ Application ID #{application.id}: '#{old_reason || 'NULL'}' → '#{new_reason}'"
      updated_count += 1
    else
      puts "✗ Failed to update Application ID #{application.id}: #{application.errors.full_messages.join(', ')}"
    end
  end
  
  puts ""
  puts "Summary:"
  puts "- Total rejected applications: #{rejected_applications.count}"
  puts "- Applications updated: #{updated_count}"
  puts "- Failed to update: #{applications_to_update.count - updated_count}"
  
  if updated_count > 0
    puts ""
    puts "Rejected reasons have been assigned."
  end
end

# Run the script
# Set force_update to true if you want to update applications that already have rejected reasons
populate_rejected_reasons(force_update: false)