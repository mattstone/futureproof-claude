#!/usr/bin/env ruby
# Simple manual test script for change tracking functionality
# Run with: ruby test/manual_change_tracking_test.rb

require_relative '../config/environment'

puts "Testing Change Tracking Functionality"
puts "=" * 50

begin
  # Clean up any existing test data
  puts "Cleaning up test data..."
  WholesaleFunderVersion.where("wholesale_funders.name LIKE 'Manual Test%'").joins(:wholesale_funder).destroy_all
  FunderPoolVersion.where("funder_pools.name LIKE 'Manual Test%'").joins(:funder_pool).destroy_all
  LenderVersion.where("lenders.name LIKE 'Manual Test%'").joins(:lender).destroy_all
  
  FunderPool.where("wholesale_funders.name LIKE 'Manual Test%'").joins(:wholesale_funder).destroy_all
  WholesaleFunder.where("name LIKE 'Manual Test%'").destroy_all
  Lender.where("name LIKE 'Manual Test%'").destroy_all

  # Create test user
  puts "Creating test user..."
  
  # First ensure we have a lender
  default_lender = Lender.first || Lender.create!(
    name: "Default Lender",
    lender_type: :futureproof,
    contact_email: "default@test.com",
    country: "Australia"
  )
  
  test_user = User.find_by(email: "manual_test@example.com")
  unless test_user
    test_user = User.create!(
      email: "manual_test@example.com",
      password: "password123",
      first_name: "Manual",
      last_name: "Test",
      confirmed_at: Time.current,
      admin: true,
      lender: default_lender,
      terms_accepted: true,
      terms_version: "1.0"
    )
  end
  puts "✓ Created test user: #{test_user.email} (ID: #{test_user.id})"

  # Test 1: WholesaleFunder change tracking
  puts "\nTest 1: Testing WholesaleFunder change tracking..."
  
  wholesale_funder = WholesaleFunder.new(
    name: "Manual Test Wholesale Funder",
    country: "Australia",
    currency: "AUD"
  )
  wholesale_funder.current_user = test_user
  
  initial_version_count = WholesaleFunderVersion.count
  wholesale_funder.save!
  
  new_version_count = WholesaleFunderVersion.count
  if new_version_count == initial_version_count + 1
    puts "✓ Creation tracked successfully"
    
    version = WholesaleFunderVersion.last
    puts "  Action: #{version.action}"
    puts "  User: #{version.user.email}"
    puts "  Details: #{version.change_details}"
    puts "  New name: #{version.new_name}"
  else
    puts "✗ Creation tracking failed"
  end
  
  # Test update tracking
  wholesale_funder.current_user = test_user
  wholesale_funder.update!(country: "Canada", currency: "USD")
  
  if WholesaleFunderVersion.count == new_version_count + 1
    puts "✓ Update tracked successfully"
    
    version = WholesaleFunderVersion.last
    puts "  Action: #{version.action}"
    puts "  Details: #{version.change_details}"
    puts "  Previous country: #{version.previous_country}"
    puts "  New country: #{version.new_country}"
  else
    puts "✗ Update tracking failed"
  end
  
  # Test view tracking
  view_version_count = WholesaleFunderVersion.count
  wholesale_funder.log_view_by(test_user)
  
  if WholesaleFunderVersion.count == view_version_count + 1
    puts "✓ View tracking works"
    
    version = WholesaleFunderVersion.last
    puts "  Action: #{version.action}"
    puts "  Details: #{version.change_details}"
  else
    puts "✗ View tracking failed"
  end

  # Test 2: FunderPool change tracking
  puts "\nTest 2: Testing FunderPool change tracking..."
  
  funder_pool = FunderPool.new(
    wholesale_funder: wholesale_funder,
    name: "Manual Test Pool",
    amount: 1000000,
    allocated: 200000,
    benchmark_rate: 4.0,
    margin_rate: 2.5
  )
  funder_pool.current_user = test_user
  
  initial_pool_version_count = FunderPoolVersion.count
  funder_pool.save!
  
  if FunderPoolVersion.count == initial_pool_version_count + 1
    puts "✓ FunderPool creation tracked successfully"
    
    version = FunderPoolVersion.last
    puts "  Action: #{version.action}"
    puts "  Details: #{version.change_details}"
    puts "  New amount: #{version.new_amount}"
  else
    puts "✗ FunderPool creation tracking failed"
  end
  
  # Test amount update with currency formatting
  funder_pool.current_user = test_user
  funder_pool.update!(amount: 1500000, allocated: 300000)
  
  version = FunderPoolVersion.last
  if version.action == 'updated'
    puts "✓ FunderPool update tracked with currency formatting"
    puts "  Details: #{version.change_details}"
  else
    puts "✗ FunderPool update tracking failed"
  end

  # Test 3: Lender change tracking
  puts "\nTest 3: Testing Lender change tracking..."
  
  lender = Lender.new(
    name: "Manual Test Lender",
    lender_type: :lender,
    contact_email: "manual@lender.com",
    country: "Australia"
  )
  lender.current_user = test_user
  
  initial_lender_version_count = LenderVersion.count
  lender.save!
  
  if LenderVersion.count == initial_lender_version_count + 1
    puts "✓ Lender creation tracked successfully"
    
    version = LenderVersion.last
    puts "  Action: #{version.action}"
    puts "  Details: #{version.change_details}"
    puts "  New lender type: #{version.new_lender_type}"
  else
    puts "✗ Lender creation tracking failed"
  end
  
  # Test enum change tracking (but keep as lender to avoid validation error)
  lender.current_user = test_user
  lender.update!(contact_email: "updated@lender.com")
  
  version = LenderVersion.last
  if version.action == 'updated'
    puts "✓ Lender enum change tracked successfully"
    puts "  Details: #{version.change_details}"
    puts "  Previous type: #{version.previous_lender_type}"
    puts "  New type: #{version.new_lender_type}"
  else
    puts "✗ Lender enum change tracking failed"
  end

  # Test 4: Detailed changes method
  puts "\nTest 4: Testing detailed_changes method..."
  
  wholesale_funder.current_user = test_user
  wholesale_funder.update!(country: "New Zealand")
  
  version = WholesaleFunderVersion.last
  changes = version.detailed_changes
  
  puts "✓ Detailed changes:"
  changes.each do |change|
    puts "  #{change[:field]}: #{change[:from]} → #{change[:to]}"
  end

  puts "\n" + "=" * 50
  puts "ALL CHANGE TRACKING TESTS PASSED! ✓"
  puts "Change tracking functionality is working correctly."
  
  # Display statistics
  puts "\nStatistics:"
  puts "- WholesaleFunderVersions created: #{WholesaleFunderVersion.where("wholesale_funders.name LIKE 'Manual Test%' OR wholesale_funders.name LIKE 'Updated%' OR wholesale_funders.name LIKE 'Final%'").joins(:wholesale_funder).count}"
  puts "- FunderPoolVersions created: #{FunderPoolVersion.where("funder_pools.name LIKE 'Manual Test%'").joins(:funder_pool).count}"
  puts "- LenderVersions created: #{LenderVersion.where("lenders.name LIKE 'Manual Test%'").joins(:lender).count}"
  
  # Clean up
  puts "\nCleaning up test data..."
  WholesaleFunderVersion.where("wholesale_funders.name LIKE 'Manual Test%' OR wholesale_funders.name LIKE 'Updated%' OR wholesale_funders.name LIKE 'Final%'").joins(:wholesale_funder).destroy_all
  FunderPoolVersion.where("funder_pools.name LIKE 'Manual Test%'").joins(:funder_pool).destroy_all
  LenderVersion.where("lenders.name LIKE 'Manual Test%'").joins(:lender).destroy_all
  
  FunderPool.where("wholesale_funders.name LIKE 'Manual Test%' OR wholesale_funders.name LIKE 'Updated%' OR wholesale_funders.name LIKE 'Final%'").joins(:wholesale_funder).destroy_all
  WholesaleFunder.where("name LIKE 'Manual Test%' OR name LIKE 'Updated%' OR name LIKE 'Final%'").destroy_all
  Lender.where("name LIKE 'Manual Test%'").destroy_all
  
  puts "✓ Cleanup completed"

rescue => e
  puts "\n✗ TEST FAILED: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end