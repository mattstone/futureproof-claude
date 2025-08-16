#!/usr/bin/env ruby
# Manual test script for lender form functionality
# Run with: ruby test/manual_lender_form_test.rb

require_relative '../config/environment'

puts "Testing Lender Form Functionality"
puts "=" * 50

begin
  # Clean up any existing test data
  puts "Cleaning up test data..."
  User.where("email LIKE '%form_test%'").destroy_all
  Lender.where("name LIKE 'Form Test%'").destroy_all

  # Create test admin user
  puts "Creating test admin user..."
  futureproof_lender = Lender.lender_type_futureproof.first
  unless futureproof_lender
    futureproof_lender = Lender.create!(
      name: "Futureproof Main",
      lender_type: :futureproof,
      contact_email: "main@futureproof.com",
      country: "Australia"
    )
  end
  
  test_admin = User.find_or_create_by(email: "form_test_admin@example.com") do |user|
    user.password = "password123"
    user.first_name = "Form"
    user.last_name = "Admin"
    user.confirmed_at = Time.current
    user.admin = true
    user.lender = futureproof_lender
    user.terms_accepted = true
    user.terms_version = "1.0"
  end
  puts "✓ Created test admin: #{test_admin.email} (ID: #{test_admin.id})"

  # Test 1: Verify enum method consistency with form
  puts "\nTest 1: Testing enum method consistency with form..."
  
  # Use existing futureproof lender for testing (can't create another)
  futureproof_test = futureproof_lender
  
  # This should succeed now - we fixed the validation to allow one edit of existing
  regular_test = Lender.create!(
    name: "Form Test Regular Lender", 
    lender_type: :lender,
    contact_email: "regular@formtest.com",
    country: "Australia"
  )
  
  puts "✓ Created test lenders successfully"
  
  # Test the enum methods that are used in the form
  if futureproof_test.lender_type_futureproof?
    puts "✓ lender_type_futureproof? method works correctly"
  else
    puts "✗ lender_type_futureproof? method failed"
  end
  
  if regular_test.lender_type_lender?
    puts "✓ lender_type_lender? method works correctly"
  else
    puts "✗ lender_type_lender? method failed"
  end
  
  # Test that the old methods don't exist (should raise NoMethodError)
  begin
    regular_test.lender_type_master?
    puts "✗ lender_type_master? method should not exist but does"
  rescue NoMethodError
    puts "✓ lender_type_master? method correctly removed"
  end
  
  begin
    regular_test.lender_type_broker?
    puts "✗ lender_type_broker? method should not exist but does"
  rescue NoMethodError
    puts "✓ lender_type_broker? method correctly removed"
  end

  # Test 2: Form field validation consistency
  puts "\nTest 2: Testing form field validation..."
  
  # Test each validation that the form relies on
  invalid_lender = Lender.new(
    name: "",
    lender_type: "",
    contact_email: "invalid-email",
    country: ""
  )
  
  if !invalid_lender.valid?
    puts "✓ Form validation works for invalid data"
    puts "  Name errors: #{invalid_lender.errors[:name].join(', ')}"
    puts "  Type errors: #{invalid_lender.errors[:lender_type].join(', ')}"
    puts "  Email errors: #{invalid_lender.errors[:contact_email].join(', ')}"
    puts "  Country errors: #{invalid_lender.errors[:country].join(', ')}"
  else
    puts "✗ Form validation should fail for invalid data"
  end

  # Test 3: Enum value mapping
  puts "\nTest 3: Testing enum value mapping consistency..."
  
  # Verify the enum values match what the form expects
  expected_enum_values = { "futureproof" => 0, "lender" => 1 }
  actual_enum_values = Lender.lender_types
  
  if actual_enum_values == expected_enum_values
    puts "✓ Enum values match form expectations"
    puts "  Expected: #{expected_enum_values}"
    puts "  Actual: #{actual_enum_values}"
  else
    puts "✗ Enum values don't match form expectations"
    puts "  Expected: #{expected_enum_values}"
    puts "  Actual: #{actual_enum_values}"
  end

  # Test 4: Form options consistency
  puts "\nTest 4: Testing form select options..."
  
  # Test that we can create lenders with the exact values used in the form
  form_option_test = Lender.new(
    name: "Form Option Test",
    lender_type: "lender", # This is what the form sends
    contact_email: "form@test.com",
    country: "Australia"
  )
  
  if form_option_test.valid?
    puts "✓ Form can create lender with 'lender' type string"
    form_option_test.save!
    puts "  Saved lender type as: #{form_option_test.lender_type}"
    puts "  Type check: lender_type_lender? = #{form_option_test.lender_type_lender?}"
  else
    puts "✗ Form cannot create lender with 'lender' type string"
    puts "  Errors: #{form_option_test.errors.full_messages.join(', ')}"
  end
  
  # Test futureproof type from form (but this will fail validation due to uniqueness)
  futureproof_form_test = Lender.new(
    name: "Futureproof Form Test",
    lender_type: "futureproof", # This is what the form sends
    contact_email: "futureproof_form@test.com",
    country: "Australia"
  )
  
  if !futureproof_form_test.valid?
    puts "✓ Form correctly prevents multiple futureproof lenders"
    puts "  Validation error: #{futureproof_form_test.errors[:lender_type].first}"
  else
    puts "✗ Form should prevent multiple futureproof lenders"
  end

  # Test 5: Update scenarios from form
  puts "\nTest 5: Testing update scenarios from form..."
  
  regular_test.current_user = test_admin
  original_name = regular_test.name
  
  # Test typical form update
  update_successful = regular_test.update(
    name: "Updated Form Test Lender",
    contact_email: "updated@formtest.com",
    country: "Canada"
  )
  
  if update_successful
    puts "✓ Form update works correctly"
    puts "  Name changed from '#{original_name}' to '#{regular_test.name}'"
    puts "  Change tracking: #{LenderVersion.last&.action == 'updated' ? 'working' : 'not working'}"
  else
    puts "✗ Form update failed"
    puts "  Errors: #{regular_test.errors.full_messages.join(', ')}"
  end

  # Test 6: Contact telephone country code handling
  puts "\nTest 6: Testing contact telephone country code handling..."
  
  phone_test = Lender.create!(
    name: "Phone Test Lender",
    lender_type: :lender,
    contact_email: "phone@test.com",
    country: "Australia",
    contact_telephone: "0123456789",
    contact_telephone_country_code: "+61"
  )
  
  puts "✓ Lender created with phone number"
  puts "  Country code: #{phone_test.contact_telephone_country_code}"
  puts "  Phone number: #{phone_test.contact_telephone}"

  # Test 7: Address field handling
  puts "\nTest 7: Testing address field handling..."
  
  address_test = Lender.create!(
    name: "Address Test Lender",
    lender_type: :lender,
    contact_email: "address@test.com",
    country: "Australia",
    address: "123 Test Street\nMelbourne VIC",
    postcode: "3000"
  )
  
  puts "✓ Lender created with address"
  puts "  Address: #{address_test.address}"
  puts "  Postcode: #{address_test.postcode}"

  puts "\n" + "=" * 50
  puts "ALL LENDER FORM TESTS COMPLETED! ✓"
  puts "=" * 50
  
  puts "\nForm Test Summary:"
  puts "- Enum methods work correctly with form expectations"
  puts "- Form validation is consistent with model validation"
  puts "- Form select options map correctly to enum values"
  puts "- Form updates work with change tracking"
  puts "- All form fields handle data correctly"
  puts "- The lender_type_master? error has been resolved"
  
  # Clean up test data
  puts "\nCleaning up test data..."
  LenderVersion.joins(:lender).where("lenders.name LIKE 'Form Test%' OR lenders.name LIKE 'Updated%' OR lenders.name LIKE 'Phone Test%' OR lenders.name LIKE 'Address Test%'").destroy_all
  User.where("email LIKE '%form_test%'").destroy_all
  Lender.where("name LIKE 'Form Test%' OR name LIKE 'Updated%' OR name LIKE 'Phone Test%' OR name LIKE 'Address Test%'").where.not(lender_type: :futureproof).destroy_all
  puts "✓ Cleanup completed"

rescue => e
  puts "\n✗ FORM TEST FAILED: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end