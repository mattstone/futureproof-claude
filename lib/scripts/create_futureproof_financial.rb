#!/usr/bin/env ruby
# Script to create Futureproof Financial master lender
# Run with: rails runner lib/scripts/create_futureproof_financial.rb

puts "🏢 Creating Futureproof Financial Master Lender"
puts "=" * 50

# Check if a master lender already exists
existing_master = Lender.lender_type_master.first
if existing_master.present?
  puts "⚠️  Master lender already exists: #{existing_master.name}"
  puts "   Deleting existing master lender to create Futureproof Financial..."
  existing_master.destroy!
  puts "✅ Existing master lender deleted"
end

# Create Futureproof Financial as the master lender
begin
  futureproof = Lender.create!(
    lender_type: :master,
    name: "Futureproof Financial",
    address: "Wework Barangaroo, Sydney",
    postcode: "2000",
    country: "Australia",
    contact_email: "info@futureprooffinancial.co",
    contact_telephone_country_code: "+61",
    contact_telephone: "0432212713"
  )
  
  puts "✅ Successfully created Futureproof Financial!"
  puts "   ID: #{futureproof.id}"
  puts "   Name: #{futureproof.name}"
  puts "   Type: #{futureproof.lender_type.humanize}"
  puts "   Address: #{futureproof.address}"
  puts "   Postcode: #{futureproof.postcode}"
  puts "   Country: #{futureproof.country}"
  puts "   Email: #{futureproof.contact_email}"
  puts "   Phone: #{futureproof.contact_telephone_country_code} #{futureproof.contact_telephone}"
  puts "   Created: #{futureproof.created_at}"
  
rescue => e
  puts "❌ Failed to create Futureproof Financial:"
  puts "   Error: #{e.message}"
  if e.respond_to?(:record) && e.record&.errors&.any?
    e.record.errors.full_messages.each do |error|
      puts "   - #{error}"
    end
  end
  exit 1
end

puts "=" * 50
puts "🎉 Futureproof Financial master lender created successfully!"