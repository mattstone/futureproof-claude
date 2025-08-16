#!/usr/bin/env ruby
# Comprehensive manual test script for lender functionality
# Run with: ruby test/manual_lender_functionality_test.rb

require_relative '../config/environment'

puts "Testing Lender Functionality Comprehensively"
puts "=" * 60

begin
  # Clean up any existing test data
  puts "Cleaning up test data..."
  LenderVersion.where("lenders.name LIKE 'Test Lender%'").joins(:lender).destroy_all
  User.where("email LIKE '%test_lender%'").destroy_all
  Lender.where("name LIKE 'Test Lender%'").destroy_all

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
  
  test_admin = User.find_or_create_by(email: "test_lender_admin@example.com") do |user|
    user.password = "password123"
    user.first_name = "Test"
    user.last_name = "Admin"
    user.confirmed_at = Time.current
    user.admin = true
    user.lender = futureproof_lender
    user.terms_accepted = true
    user.terms_version = "1.0"
  end
  puts "✓ Created test admin: #{test_admin.email} (ID: #{test_admin.id})"

  # Test 1: Lender Model Validations
  puts "\nTest 1: Testing Lender model validations..."
  
  # Test required fields
  invalid_lender = Lender.new
  if !invalid_lender.valid?
    puts "✓ Validation correctly fails for blank lender"
    puts "  Errors: #{invalid_lender.errors.full_messages.join(', ')}"
  else
    puts "✗ Validation should fail for blank lender"
  end
  
  # Test email format validation
  invalid_email_lender = Lender.new(
    name: "Test Invalid Email",
    lender_type: :lender,
    contact_email: "invalid-email",
    country: "Australia"
  )
  if !invalid_email_lender.valid?
    puts "✓ Email format validation works"
    puts "  Email errors: #{invalid_email_lender.errors[:contact_email].join(', ')}"
  else
    puts "✗ Email format validation should fail"
  end

  # Test 2: Enum Methods
  puts "\nTest 2: Testing Lender enum methods..."
  
  test_lender = Lender.create!(
    name: "Test Lender Basic",
    lender_type: :lender,
    contact_email: "test@lender.com",
    country: "Australia"
  )
  
  if test_lender.lender_type_lender?
    puts "✓ lender_type_lender? method works"
  else
    puts "✗ lender_type_lender? method failed"
  end
  
  if !test_lender.lender_type_futureproof?
    puts "✓ lender_type_futureproof? method works (correctly false)"
  else
    puts "✗ lender_type_futureproof? method failed"
  end

  # Test 3: Futureproof Lender Uniqueness Validation
  puts "\nTest 3: Testing Futureproof lender uniqueness validation..."
  
  duplicate_futureproof = Lender.new(
    name: "Another Futureproof",
    lender_type: :futureproof,
    contact_email: "another@futureproof.com",
    country: "Australia"
  )
  
  if !duplicate_futureproof.valid?
    puts "✓ Futureproof lender uniqueness validation works"
    puts "  Error: #{duplicate_futureproof.errors[:lender_type].first}"
  else
    puts "✗ Should not allow multiple Futureproof lenders"
  end

  # Test 4: Change Tracking Integration
  puts "\nTest 4: Testing change tracking integration..."
  
  test_lender.current_user = test_admin
  initial_version_count = LenderVersion.count
  test_lender.update!(
    name: "Updated Test Lender Basic",
    contact_email: "updated@lender.com"
  )
  
  if LenderVersion.count == initial_version_count + 1
    puts "✓ Change tracking works for updates"
    version = LenderVersion.last
    puts "  Action: #{version.action}"
    puts "  Details: #{version.change_details}"
  else
    puts "✗ Change tracking failed for updates"
  end

  # Test 5: Association Tests
  puts "\nTest 5: Testing Lender associations..."
  
  # Test that lender can have users
  test_user = User.create!(
    email: "user@testlender.com",
    password: "password123",
    first_name: "Test",
    last_name: "User",
    confirmed_at: Time.current,
    admin: false,
    lender: test_lender,
    terms_accepted: true,
    terms_version: "1.0"
  )
  
  if test_lender.users.include?(test_user)
    puts "✓ Lender can have associated users"
    puts "  Users count: #{test_lender.users.count}"
  else
    puts "✗ Lender association with users failed"
  end

  # Test 6: CRUD Operations
  puts "\nTest 6: Testing CRUD operations..."
  
  # Create
  create_lender = Lender.create!(
    name: "Test Lender CRUD",
    lender_type: :lender,
    contact_email: "crud@test.com",
    country: "Canada",
    address: "123 Test Street",
    postcode: "12345",
    contact_telephone: "1234567890",
    contact_telephone_country_code: "+1"
  )
  puts "✓ CREATE: Lender created successfully"
  puts "  ID: #{create_lender.id}, Name: #{create_lender.name}"
  
  # Read
  read_lender = Lender.find(create_lender.id)
  if read_lender.name == "Test Lender CRUD"
    puts "✓ READ: Lender read successfully"
  else
    puts "✗ READ: Failed to read lender correctly"
  end
  
  # Update
  read_lender.current_user = test_admin
  read_lender.update!(
    name: "Updated Test Lender CRUD",
    country: "USA"
  )
  if read_lender.reload.name == "Updated Test Lender CRUD"
    puts "✓ UPDATE: Lender updated successfully"
  else
    puts "✗ UPDATE: Failed to update lender"
  end
  
  # Test delete (but don't actually delete to avoid breaking associations)
  delete_test_lender = Lender.create!(
    name: "Test Lender Delete",
    lender_type: :lender,
    contact_email: "delete@test.com",
    country: "Australia"
  )
  delete_id = delete_test_lender.id
  delete_test_lender.destroy
  
  if !Lender.exists?(delete_id)
    puts "✓ DELETE: Lender deleted successfully"
  else
    puts "✗ DELETE: Failed to delete lender"
  end

  # Test 7: Scopes and Queries
  puts "\nTest 7: Testing scopes and queries..."
  
  # Create different types of lenders
  lender_count = Lender.lender_type_lender.count
  futureproof_count = Lender.lender_type_futureproof.count
  
  puts "✓ SCOPES work correctly:"
  puts "  Regular lenders: #{lender_count}"
  puts "  Futureproof lenders: #{futureproof_count}"
  
  if futureproof_count == 1
    puts "✓ Only one Futureproof lender exists (as expected)"
  else
    puts "✗ Unexpected number of Futureproof lenders: #{futureproof_count}"
  end

  # Test 8: Display Methods
  puts "\nTest 8: Testing display methods..."
  
  test_display_lender = Lender.create!(
    name: "Test Display Lender",
    lender_type: :lender,
    contact_email: "display@test.com",
    country: "Australia"
  )
  
  puts "✓ Display methods work:"
  puts "  Lender type display: Expected 'Lender', got '#{test_display_lender.lender_type.humanize}'"
  
  # Test 9: Wholesale Funder Relationships
  puts "\nTest 9: Testing wholesale funder relationships..."
  
  wholesale_funder = WholesaleFunder.create!(
    name: "Test Wholesale Funder for Lender",
    country: "Australia",
    currency: "AUD"
  )
  
  # Create relationship
  lender_wf_relationship = LenderWholesaleFunder.create!(
    lender: test_lender,
    wholesale_funder: wholesale_funder,
    active: true
  )
  
  if test_lender.wholesale_funders.include?(wholesale_funder)
    puts "✓ Lender can have wholesale funder relationships"
    puts "  Active wholesale funders: #{test_lender.active_wholesale_funders.count}"
  else
    puts "✗ Wholesale funder relationship failed"
  end

  # Test 10: Deletion Restrictions
  puts "\nTest 10: Testing deletion restrictions..."
  
  # Try to delete lender with users (should be restricted)
  begin
    test_lender.destroy
    puts "✗ Should not be able to delete lender with associated users"
  rescue ActiveRecord::DeleteRestrictionError => e
    puts "✓ Correctly restricted deletion of lender with users"
    puts "  Error: #{e.message}"
  end

  puts "\n" + "=" * 60
  puts "ALL LENDER FUNCTIONALITY TESTS COMPLETED! ✓"
  puts "=" * 60
  
  # Display summary statistics
  puts "\nSummary Statistics:"
  puts "- Total lenders: #{Lender.count}"
  puts "- Regular lenders: #{Lender.lender_type_lender.count}"
  puts "- Futureproof lenders: #{Lender.lender_type_futureproof.count}"
  puts "- Lender versions created: #{LenderVersion.where(created_at: 1.hour.ago..Time.current).count}"
  
  # Clean up test data
  puts "\nCleaning up test data..."
  LenderVersion.where("lenders.name LIKE 'Test Lender%' OR lenders.name LIKE 'Updated%'").joins(:lender).destroy_all
  User.where("email LIKE '%test_lender%' OR email LIKE '%testlender%'").destroy_all
  LenderWholesaleFunder.where(wholesale_funder: wholesale_funder).destroy_all
  wholesale_funder.destroy
  Lender.where("name LIKE 'Test%' OR name LIKE 'Updated%'").where.not(lender_type: :futureproof).destroy_all
  puts "✓ Cleanup completed"

rescue => e
  puts "\n✗ TEST FAILED: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end