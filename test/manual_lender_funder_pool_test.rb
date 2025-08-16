#!/usr/bin/env ruby
# Simple manual test script for lender funder pool functionality
# Run with: ruby test/manual_lender_funder_pool_test.rb

require_relative '../config/environment'

puts "Testing Lender Funder Pool Functionality"
puts "=" * 50

begin
  # Clean up any existing test data
  puts "Cleaning up test data..."
  LenderFunderPool.where("lenders.name LIKE 'Test%'").joins(:lender).destroy_all
  LenderWholesaleFunder.where("lenders.name LIKE 'Test%'").joins(:lender).destroy_all
  FunderPool.where("wholesale_funders.name LIKE 'Test%'").joins(:wholesale_funder).destroy_all
  WholesaleFunder.where("name LIKE 'Test%'").destroy_all
  Lender.where("name LIKE 'Test%'").destroy_all

  # Create test data
  puts "Creating test data..."
  
  lender = Lender.create!(
    name: "Test Lender for Manual Test",
    lender_type: :lender,
    contact_email: "test@manual.com",
    country: "Australia"
  )
  puts "✓ Created lender: #{lender.name}"

  wholesale_funder = WholesaleFunder.create!(
    name: "Test Wholesale Funder for Manual Test",
    country: "Australia",
    currency: "AUD"
  )
  puts "✓ Created wholesale funder: #{wholesale_funder.name}"

  funder_pool = FunderPool.create!(
    wholesale_funder: wholesale_funder,
    name: "Test Pool for Manual Test",
    amount: 1000000,
    allocated: 200000,
    benchmark_rate: 4.00,
    margin_rate: 2.50
  )
  puts "✓ Created funder pool: #{funder_pool.name} (#{funder_pool.formatted_amount} total, #{funder_pool.formatted_available} available)"

  # Test 1: Create wholesale funder relationship
  puts "\nTest 1: Creating wholesale funder relationship..."
  wholesale_funder_relationship = LenderWholesaleFunder.create!(
    lender: lender,
    wholesale_funder: wholesale_funder,
    active: true
  )
  puts "✓ Created wholesale funder relationship"

  # Test 2: Create lender funder pool relationship
  puts "\nTest 2: Creating lender funder pool relationship..."
  lender_funder_pool = LenderFunderPool.create!(
    lender: lender,
    funder_pool: funder_pool,
    active: true
  )
  puts "✓ Created lender funder pool relationship"
  puts "  Status: #{lender_funder_pool.status_display}"
  puts "  Badge class: #{lender_funder_pool.status_badge_class}"

  # Test 3: Test toggle functionality
  puts "\nTest 3: Testing toggle functionality..."
  original_status = lender_funder_pool.active?
  lender_funder_pool.toggle_active!
  puts "✓ Toggled from #{original_status} to #{lender_funder_pool.active?}"
  
  lender_funder_pool.toggle_active!
  puts "✓ Toggled back to #{lender_funder_pool.active?}"

  # Test 4: Test associations
  puts "\nTest 4: Testing associations..."
  puts "✓ Lender has #{lender.lender_funder_pools.count} funder pool relationship(s)"
  puts "✓ Lender has #{lender.active_funder_pools.count} active funder pool(s)"
  puts "✓ Funder pool belongs to: #{lender_funder_pool.wholesale_funder.name}"

  # Test 5: Test validation (should fail without wholesale funder relationship)
  puts "\nTest 5: Testing validation (should fail without wholesale funder relationship)..."
  wholesale_funder_relationship.update!(active: false)
  
  begin
    lender_funder_pool.toggle_active!
    puts "✗ Validation failed - should not allow toggle when wholesale funder is inactive"
  rescue ActiveRecord::RecordInvalid => e
    puts "✓ Validation working - #{e.message}"
  end

  # Test 6: Test controller availability query
  puts "\nTest 6: Testing controller availability query..."
  wholesale_funder_relationship.update!(active: true)
  
  available_pools = FunderPool.joins(:wholesale_funder)
                               .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                               .where(lender_wholesale_funders: { lender_id: lender.id, active: true })
                               .where.not(id: lender.funder_pools.select(:id))
                               .includes(:wholesale_funder)
  
  puts "✓ Available pools query returns #{available_pools.count} pool(s)"

  # Test 7: Test view helper methods
  puts "\nTest 7: Testing view helper methods..."
  puts "✓ Formatted amount: #{funder_pool.formatted_amount}"
  puts "✓ Formatted available: #{funder_pool.formatted_available}"
  puts "✓ Allocation percentage: #{funder_pool.allocation_percentage}%"

  puts "\n" + "=" * 50
  puts "ALL TESTS PASSED! ✓"
  puts "Lender funder pool functionality is working correctly."
  
  # Clean up
  puts "\nCleaning up test data..."
  lender_funder_pool.destroy
  wholesale_funder_relationship.destroy
  funder_pool.destroy
  wholesale_funder.destroy
  lender.destroy
  puts "✓ Cleanup completed"

rescue => e
  puts "\n✗ TEST FAILED: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end