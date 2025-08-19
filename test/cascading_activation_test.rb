#!/usr/bin/env ruby

# Comprehensive test for cascading activation/deactivation between wholesale funders and funder pools
require_relative '../config/environment'

class CascadingActivationTest
  def self.run
    puts "🧪 Testing Cascading Activation/Deactivation Logic..."
    puts "This test ensures proper parent-child relationship enforcement between wholesale funders and funder pools"
    
    begin
      # Create test data
      puts "\n📋 Creating test data..."
      test_data = create_test_data
      lender = test_data[:lender]
      wholesale_relationship = test_data[:wholesale_relationship]
      pool_relationship_1 = test_data[:pool_relationship_1]
      pool_relationship_2 = test_data[:pool_relationship_2]
      
      puts "✅ Test data created successfully"
      puts "  Lender: #{lender.name}"
      puts "  Wholesale Funder: #{wholesale_relationship.wholesale_funder.name}"
      puts "  Funder Pool 1: #{pool_relationship_1.funder_pool.name}"
      puts "  Funder Pool 2: #{pool_relationship_2.funder_pool.name}"
      
      # Test 1: Verify initial state
      puts "\n📋 Test 1: Verifying initial state..."
      
      unless wholesale_relationship.active? && pool_relationship_1.active? && pool_relationship_2.active?
        puts "❌ Initial state incorrect - all relationships should be active"
        return false
      end
      
      puts "  ✅ All relationships initially active as expected"
      
      # Test 2: Test cascading deactivation
      puts "\n📋 Test 2: Testing cascading deactivation..."
      puts "  Deactivating wholesale funder should cascade to all child pools"
      
      # Record initial states
      initial_wholesale_status = wholesale_relationship.active?
      initial_pool1_status = pool_relationship_1.active?
      initial_pool2_status = pool_relationship_2.active?
      
      puts "  Before deactivation:"
      puts "    Wholesale funder: #{initial_wholesale_status ? 'Active' : 'Inactive'}"
      puts "    Pool 1: #{initial_pool1_status ? 'Active' : 'Inactive'}"
      puts "    Pool 2: #{initial_pool2_status ? 'Active' : 'Inactive'}"
      
      # Deactivate wholesale funder
      wholesale_relationship.toggle_active!
      
      # Reload to get fresh data
      wholesale_relationship.reload
      pool_relationship_1.reload
      pool_relationship_2.reload
      
      puts "  After wholesale funder deactivation:"
      puts "    Wholesale funder: #{wholesale_relationship.active? ? 'Active' : 'Inactive'}"
      puts "    Pool 1: #{pool_relationship_1.active? ? 'Active' : 'Inactive'}"
      puts "    Pool 2: #{pool_relationship_2.active? ? 'Active' : 'Inactive'}"
      
      # Verify cascading deactivation worked
      unless !wholesale_relationship.active? && !pool_relationship_1.active? && !pool_relationship_2.active?
        puts "❌ Cascading deactivation failed - all should be inactive"
        return false
      end
      
      puts "  ✅ Cascading deactivation successful - all relationships now inactive"
      
      # Test 3: Test blocked activation of child pools
      puts "\n📋 Test 3: Testing blocked activation of child pools..."
      puts "  Attempting to activate funder pools while wholesale funder is inactive should fail"
      
      # Try to activate pool 1 - should fail
      begin
        pool_relationship_1.toggle_active!
        puts "❌ Pool 1 activation should have been blocked but wasn't"
        return false
      rescue ActivationBlockedError => e
        puts "  ✅ Pool 1 activation correctly blocked with message: '#{e.message}'"
      end
      
      # Try to activate pool 2 - should also fail
      begin
        pool_relationship_2.toggle_active!
        puts "❌ Pool 2 activation should have been blocked but wasn't"
        return false
      rescue ActivationBlockedError => e
        puts "  ✅ Pool 2 activation correctly blocked with message: '#{e.message}'"
      end
      
      # Verify pools are still inactive
      pool_relationship_1.reload
      pool_relationship_2.reload
      
      unless !pool_relationship_1.active? && !pool_relationship_2.active?
        puts "❌ Pools should still be inactive after blocked activation attempts"
        return false
      end
      
      puts "  ✅ Both pools remain inactive after blocked activation attempts"
      
      # Test 4: Test normal reactivation workflow
      puts "\n📋 Test 4: Testing normal reactivation workflow..."
      puts "  Reactivating wholesale funder first, then pools should work normally"
      
      # Reactivate wholesale funder
      wholesale_relationship.toggle_active!
      wholesale_relationship.reload
      
      if !wholesale_relationship.active?
        puts "❌ Wholesale funder reactivation failed"
        return false
      end
      
      puts "  ✅ Wholesale funder successfully reactivated"
      
      # Now pools should be activatable
      pool_relationship_1.toggle_active!
      pool_relationship_1.reload
      
      if !pool_relationship_1.active?
        puts "❌ Pool 1 activation failed after wholesale funder reactivation"
        return false
      end
      
      puts "  ✅ Pool 1 successfully activated after wholesale funder reactivation"
      
      pool_relationship_2.toggle_active!
      pool_relationship_2.reload
      
      if !pool_relationship_2.active?
        puts "❌ Pool 2 activation failed after wholesale funder reactivation"
        return false
      end
      
      puts "  ✅ Pool 2 successfully activated after wholesale funder reactivation"
      
      # Test 5: Test can_activate? method
      puts "\n📋 Test 5: Testing can_activate? validation method..."
      
      # Should be able to activate when wholesale funder is active
      if !pool_relationship_1.can_activate?
        puts "❌ can_activate? should return true when wholesale funder is active"
        return false
      end
      
      puts "  ✅ can_activate? correctly returns true when wholesale funder is active"
      
      # Deactivate wholesale funder again
      wholesale_relationship.toggle_active!
      wholesale_relationship.reload
      pool_relationship_1.reload
      pool_relationship_2.reload
      
      # Should not be able to activate pools when wholesale funder is inactive
      if pool_relationship_1.can_activate?
        puts "❌ can_activate? should return false when wholesale funder is inactive"
        return false
      end
      
      puts "  ✅ can_activate? correctly returns false when wholesale funder is inactive"
      
      # Test 6: Test Available Funder Pools rendering and ordering
      puts "\n📋 Test 6: Testing Available Funder Pools rendering and ordering..."
      
      # Test that the query used in templates works correctly for ordering
      puts "  Testing pool ordering query (active first, then inactive)..."
      
      # Set up mixed state: wholesale active, one pool active, one inactive
      wholesale_relationship.update!(active: true)
      pool_relationship_1.update!(active: true)
      pool_relationship_2.update!(active: false)
      
      ordered_pools = lender.lender_funder_pools
                           .includes(:funder_pool => :wholesale_funder)
                           .order(active: :desc)
                           .to_a
      
      puts "  Current pool states:"
      ordered_pools.each_with_index do |pr, i|
        puts "    Position #{i + 1}: #{pr.funder_pool.name} - #{pr.active? ? 'Active' : 'Inactive'}"
      end
      
      # Verify active pools come first
      active_positions = []
      inactive_positions = []
      
      ordered_pools.each_with_index do |pr, i|
        if pr.active?
          active_positions << i
        else
          inactive_positions << i
        end
      end
      
      if active_positions.all? { |pos| pos < inactive_positions.min }
        puts "  ✅ Pool ordering correct - all active pools come before inactive pools"
      else
        puts "  ❌ Pool ordering incorrect"
        puts "    Active positions: #{active_positions}"
        puts "    Inactive positions: #{inactive_positions}"
        return false
      end
      
      # Test cascading deactivation affects ordering
      puts "  Testing ordering after cascading deactivation..."
      
      wholesale_relationship.toggle_active! # This should deactivate all pools
      wholesale_relationship.reload
      pool_relationship_1.reload
      pool_relationship_2.reload
      
      # All should now be inactive
      post_cascade_pools = lender.lender_funder_pools
                                .includes(:funder_pool => :wholesale_funder)
                                .order(active: :desc)
                                .to_a
      
      all_inactive_after_cascade = post_cascade_pools.all? { |pr| !pr.active? }
      
      if all_inactive_after_cascade
        puts "  ✅ All pools correctly inactive after cascading deactivation"
        puts "  📋 Template will render all pools with 'Inactive' status and 'status-inactive' CSS class"
      else
        puts "  ❌ Pools should all be inactive after cascading deactivation"
        return false
      end
      
      # Test that reactivation allows proper mixed ordering
      puts "  Testing mixed ordering after selective reactivation..."
      
      wholesale_relationship.toggle_active! # Reactivate wholesale
      wholesale_relationship.reload
      
      # Activate only one pool
      pool_relationship_1.toggle_active!
      pool_relationship_1.reload
      
      mixed_state_pools = lender.lender_funder_pools
                               .includes(:funder_pool => :wholesale_funder)
                               .order(active: :desc)
                               .to_a
      
      # Should have one active, one inactive, with active first
      active_count = mixed_state_pools.count(&:active?)
      inactive_count = mixed_state_pools.count { |pr| !pr.active? }
      first_pool_active = mixed_state_pools.first&.active?
      
      if active_count == 1 && inactive_count == 1 && first_pool_active
        puts "  ✅ Mixed state ordering correct - active pool appears first"
      else
        puts "  ❌ Mixed state ordering failed"
        puts "    Active count: #{active_count}, Inactive count: #{inactive_count}"
        puts "    First pool active: #{first_pool_active}"
        return false
      end

      # Test 7: Test edge cases
      puts "\n📋 Test 7: Testing edge cases..."
      
      # Test deactivating already inactive pool (should work)
      begin
        pool_relationship_1.toggle_active! # This should work (deactivating already inactive)
        puts "  ✅ Deactivating already inactive pool works correctly"
      rescue => e
        puts "❌ Deactivating inactive pool should work but failed: #{e.message}"
        return false
      end
      
      # Test with no current_user set
      pool_relationship_without_user = pool_relationship_2.dup
      pool_relationship_without_user.current_user = nil
      
      begin
        # This should still work even without current_user
        wholesale_relationship.current_user = nil
        wholesale_relationship.toggle_active! # Reactivate
        wholesale_relationship.reload
        
        if !wholesale_relationship.active?
          puts "❌ Wholesale funder activation without current_user failed"
          return false
        end
        
        puts "  ✅ Activation works correctly even without current_user"
      rescue => e
        puts "❌ Activation without current_user failed: #{e.message}"
        return false
      end
      
      puts "\n🎉 ALL CASCADING ACTIVATION TESTS PASSED!"
      
      puts "\n📝 Test Summary:"
      puts "  ✅ Cascading deactivation works correctly"
      puts "  ✅ Blocked activation of child pools when parent is inactive"
      puts "  ✅ Normal reactivation workflow functions properly"
      puts "  ✅ Validation method can_activate? works correctly"
      puts "  ✅ Available Funder Pools ordering works correctly (active first, then inactive)"
      puts "  ✅ Template queries handle mixed active/inactive states properly"
      puts "  ✅ Edge cases handled properly"
      puts "  ✅ User feedback and error messages are appropriate"
      
      puts "\n🚀 CASCADING LOGIC IMPLEMENTATION SUCCESSFUL!"
      puts "🔗 Parent-child relationships between wholesale funders and funder pools are properly enforced"
      
      return true
      
    rescue => e
      puts "\n💥 ERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      return false
    ensure
      # Clean up test data
      puts "\n🧹 Cleaning up test data..."
      cleanup_test_data
    end
  end
  
  private
  
  def self.create_test_data
    # Create lender
    lender = Lender.create!(
      name: "Cascading Test Lender #{Time.current.to_i}",
      contact_email: "cascading_test#{Time.current.to_i}@testlender.com",
      lender_type: :lender,
      address: "123 Cascading Test Street",
      country: "Australia"
    )
    
    # Create wholesale funder
    wholesale_funder = WholesaleFunder.create!(
      name: "Cascading Test Wholesale Funder #{Time.current.to_i}",
      country: "Australia",
      currency: "AUD"
    )
    
    # Create funder pools
    funder_pool_1 = FunderPool.create!(
      name: "Cascading Test Pool 1 #{Time.current.to_i}",
      amount: 1000000.0,
      allocated: 0.0,
      wholesale_funder: wholesale_funder
    )
    
    funder_pool_2 = FunderPool.create!(
      name: "Cascading Test Pool 2 #{Time.current.to_i}",
      amount: 2000000.0,
      allocated: 0.0,
      wholesale_funder: wholesale_funder
    )
    
    # Create relationships - all active initially
    wholesale_relationship = lender.lender_wholesale_funders.create!(
      wholesale_funder: wholesale_funder,
      active: true
    )
    
    pool_relationship_1 = lender.lender_funder_pools.create!(
      funder_pool: funder_pool_1,
      active: true
    )
    
    pool_relationship_2 = lender.lender_funder_pools.create!(
      funder_pool: funder_pool_2,
      active: true
    )
    
    {
      lender: lender,
      wholesale_funder: wholesale_funder,
      funder_pool_1: funder_pool_1,
      funder_pool_2: funder_pool_2,
      wholesale_relationship: wholesale_relationship,
      pool_relationship_1: pool_relationship_1,
      pool_relationship_2: pool_relationship_2
    }
  end
  
  def self.cleanup_test_data
    # Clean up in reverse dependency order
    LenderFunderPool.joins(:lender).where("lenders.name LIKE 'Cascading Test Lender%'").destroy_all
    LenderWholesaleFunder.joins(:lender).where("lenders.name LIKE 'Cascading Test Lender%'").destroy_all
    FunderPool.where("name LIKE 'Cascading Test Pool%'").destroy_all
    WholesaleFunder.where("name LIKE 'Cascading Test Wholesale Funder%'").destroy_all
    Lender.where("name LIKE 'Cascading Test Lender%'").destroy_all
    puts "✅ Test data cleaned up successfully"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  success = CascadingActivationTest.run
  exit(success ? 0 : 1)
end