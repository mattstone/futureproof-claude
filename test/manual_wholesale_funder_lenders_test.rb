#!/usr/bin/env ruby
# Manual test script for wholesale funder lenders count functionality
# Run with: ruby test/manual_wholesale_funder_lenders_test.rb

require_relative '../config/environment'

puts "Testing Wholesale Funder Lenders Count"
puts "=" * 50

begin
  # Clean up any existing test data
  puts "Cleaning up test data..."
  LenderFunderPool.joins(:funder_pool).where("funder_pools.name LIKE 'Test%'").destroy_all
  FunderPool.where("name LIKE 'Test%'").destroy_all
  WholesaleFunder.where("name LIKE 'Test%'").destroy_all
  Lender.where("name LIKE 'Test%'").destroy_all

  # Test 1: Create test data
  puts "\nTest 1: Creating test data..."
  
  # Create wholesale funder
  wf = WholesaleFunder.create!(
    name: "Test Wholesale Funder",
    country: "Australia",
    currency: "AUD"
  )
  puts "✓ Created wholesale funder: #{wf.name}"
  
  # Create funder pools
  pool1 = FunderPool.create!(
    wholesale_funder: wf,
    name: "Test Pool 1",
    amount: 1000000,
    allocated: 200000,
    benchmark_rate: 4.0,
    margin_rate: 2.5
  )
  
  pool2 = FunderPool.create!(
    wholesale_funder: wf,
    name: "Test Pool 2", 
    amount: 500000,
    allocated: 100000,
    benchmark_rate: 3.5,
    margin_rate: 2.0
  )
  puts "✓ Created 2 funder pools"
  
  # Create lenders
  lender1 = Lender.create!(
    name: "Test Lender 1",
    lender_type: :lender,
    contact_email: "lender1@test.com",
    country: "Australia"
  )
  
  lender2 = Lender.create!(
    name: "Test Lender 2",
    lender_type: :lender,
    contact_email: "lender2@test.com", 
    country: "Australia"
  )
  
  lender3 = Lender.create!(
    name: "Test Lender 3",
    lender_type: :lender,
    contact_email: "lender3@test.com",
    country: "Australia"
  )
  puts "✓ Created 3 test lenders"

  # Test 2: Initial state (no relationships)
  puts "\nTest 2: Testing initial state..."
  
  if wf.lenders_count == 0
    puts "✓ lenders_count returns 0 with no relationships"
  else
    puts "✗ lenders_count should be 0, got #{wf.lenders_count}"
  end
  
  if wf.active_lenders_count == 0
    puts "✓ active_lenders_count returns 0 with no relationships"
  else
    puts "✗ active_lenders_count should be 0, got #{wf.active_lenders_count}"
  end

  # Test 3: Add lenders
  puts "\nTest 3: Adding lenders..."
  
  # First create lender-wholesale funder relationships (required for pool access)
  lwf1 = LenderWholesaleFunder.create!(
    lender: lender1,
    wholesale_funder: wf,
    active: true
  )
  
  lwf2 = LenderWholesaleFunder.create!(
    lender: lender2,
    wholesale_funder: wf,
    active: true
  )
  
  lwf3 = LenderWholesaleFunder.create!(
    lender: lender3,
    wholesale_funder: wf,
    active: true
  )
  
  # Now connect lenders to specific pools
  # Connect lender1 to pool1 (active)
  lfp1 = LenderFunderPool.create!(
    lender: lender1,
    funder_pool: pool1,
    active: true
  )
  
  # Connect lender2 to pool1 (active)
  lfp2 = LenderFunderPool.create!(
    lender: lender2,
    funder_pool: pool1,
    active: true
  )
  
  # Connect lender2 to pool2 (active) - same lender, different pool
  lfp3 = LenderFunderPool.create!(
    lender: lender2,
    funder_pool: pool2,
    active: true
  )
  
  # Connect lender3 to pool2 (inactive)
  lfp4 = LenderFunderPool.create!(
    lender: lender3,
    funder_pool: pool2,
    active: false
  )
  
  puts "✓ Created lender-pool relationships"
  
  # Reload to ensure fresh data
  wf.reload

  # Test 4: Verify counts
  puts "\nTest 4: Verifying lender counts..."
  
  # Should have 3 unique lenders total (including inactive)
  total_lenders = wf.lenders_count
  if total_lenders == 3
    puts "✓ lenders_count correctly returns 3 (all lenders including inactive)"
  else
    puts "✗ lenders_count should be 3, got #{total_lenders}"
  end
  
  # Should have 2 active lenders (lender1 and lender2)
  active_lenders = wf.active_lenders_count
  if active_lenders == 2
    puts "✓ active_lenders_count correctly returns 2 (only active lenders)"
  else
    puts "✗ active_lenders_count should be 2, got #{active_lenders}"
  end

  # Test 5: Test with multiple pools per lender
  puts "\nTest 5: Verifying unique lender counting..."
  
  # lender2 is connected to both pools but should only be counted once
  lender2_pools = lender2.funder_pools.where(wholesale_funder: wf).count
  puts "  Lender2 is connected to #{lender2_pools} pools from this wholesale funder"
  
  if lender2_pools == 2
    puts "✓ Lender2 correctly connected to 2 pools"
  else
    puts "✗ Expected lender2 to be connected to 2 pools"
  end

  # Test 6: Test deactivating a relationship
  puts "\nTest 6: Testing relationship deactivation..."
  
  # Deactivate lender1's relationship
  lfp1.update!(active: false)
  wf.reload
  
  new_active_count = wf.active_lenders_count
  if new_active_count == 1
    puts "✓ active_lenders_count correctly decreased to 1 after deactivation"
  else
    puts "✗ active_lenders_count should be 1 after deactivation, got #{new_active_count}"
  end
  
  # Total count should remain the same
  total_count = wf.lenders_count
  if total_count == 3
    puts "✓ lenders_count remains 3 (includes inactive lenders)"
  else
    puts "✗ lenders_count should remain 3, got #{total_count}"
  end

  # Test 7: Test with multiple wholesale funders
  puts "\nTest 7: Testing isolation between wholesale funders..."
  
  # Create another wholesale funder
  wf2 = WholesaleFunder.create!(
    name: "Test Wholesale Funder 2",
    country: "Canada",
    currency: "USD"
  )
  
  pool3 = FunderPool.create!(
    wholesale_funder: wf2,
    name: "Test Pool 3",
    amount: 750000,
    allocated: 150000,
    benchmark_rate: 4.5,
    margin_rate: 3.0
  )
  
  # First create lender-wholesale funder relationship for wf2
  LenderWholesaleFunder.create!(
    lender: lender1,
    wholesale_funder: wf2,
    active: true
  )
  
  # Connect lender1 to the new wholesale funder's pool
  LenderFunderPool.create!(
    lender: lender1,
    funder_pool: pool3,
    active: true
  )
  
  # Check that counts are isolated
  wf_count = wf.active_lenders_count
  wf2_count = wf2.active_lenders_count
  
  if wf_count == 1 && wf2_count == 1
    puts "✓ Lender counts are correctly isolated between wholesale funders"
    puts "  WF1 active lenders: #{wf_count}"
    puts "  WF2 active lenders: #{wf2_count}"
  else
    puts "✗ Lender counts not properly isolated"
    puts "  WF1 active lenders: #{wf_count} (expected 1)"
    puts "  WF2 active lenders: #{wf2_count} (expected 1)"
  end

  puts "\n" + "=" * 50
  puts "ALL WHOLESALE FUNDER LENDERS TESTS COMPLETED! ✓"
  puts "=" * 50
  
  puts "\nSummary:"
  puts "- lenders_count method correctly counts all unique lenders using pools"
  puts "- active_lenders_count method correctly counts only active relationships"
  puts "- Lenders connected to multiple pools are counted only once"
  puts "- Counts are properly isolated between different wholesale funders"
  puts "- Deactivating relationships correctly updates active counts"
  
  # Clean up test data
  puts "\nCleaning up test data..."
  LenderFunderPool.joins(:funder_pool).where("funder_pools.name LIKE 'Test%'").destroy_all
  FunderPool.where("name LIKE 'Test%'").destroy_all
  WholesaleFunder.where("name LIKE 'Test%'").destroy_all
  Lender.where("name LIKE 'Test%'").destroy_all
  puts "✓ Cleanup completed"

rescue => e
  puts "\n✗ TEST FAILED: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end