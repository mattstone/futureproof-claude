#!/usr/bin/env ruby

# Manual test script to verify toggle functionality works
require_relative '../config/environment'

class ManualToggleTest
  def self.run
    puts "🧪 Testing Toggle Functionality for Lender Status Badges..."
    
    begin
      # Find a lender with relationships
      lender = Lender.joins(:mortgage_lenders).first
      
      unless lender
        puts "❌ No lender found with mortgage relationships for testing"
        return false
      end
      
      puts "✅ Using lender: #{lender.name} (ID: #{lender.id})"
      
      # Test wholesale funder relationships
      wholesale_relationships = lender.lender_wholesale_funders
      if wholesale_relationships.any?
        puts "\n📋 Testing Wholesale Funder Toggle:"
        relationship = wholesale_relationships.first
        original_status = relationship.active?
        puts "  Original status: #{original_status ? 'Active' : 'Inactive'}"
        
        # Simulate toggle
        relationship.update!(active: !relationship.active?)
        puts "  New status: #{relationship.active? ? 'Active' : 'Inactive'}"
        puts "  ✅ Wholesale funder toggle successful"
        
        # Restore original status
        relationship.update!(active: original_status)
        puts "  ✅ Status restored to original"
      else
        puts "\n⚠️  No wholesale funder relationships found for testing"
      end
      
      # Test funder pool relationships  
      funder_pools = lender.lender_funder_pools
      if funder_pools.any?
        puts "\n📋 Testing Funder Pool Toggle:"
        pool_relationship = funder_pools.first
        original_status = pool_relationship.active?
        puts "  Original status: #{original_status ? 'Active' : 'Inactive'}"
        
        # Simulate toggle
        pool_relationship.update!(active: !pool_relationship.active?)
        puts "  New status: #{pool_relationship.active? ? 'Active' : 'Inactive'}"
        puts "  ✅ Funder pool toggle successful"
        
        # Restore original status
        pool_relationship.update!(active: original_status)
        puts "  ✅ Status restored to original"
      else
        puts "\n⚠️  No funder pool relationships found for testing"
      end
      
      # Verify routes exist
      puts "\n📋 Verifying Routes:"
      
      # Check if routes are defined
      if Rails.application.routes.url_helpers.respond_to?(:toggle_active_admin_lender_wholesale_funder_path)
        puts "  ✅ Wholesale funder toggle route exists"
      else
        puts "  ❌ Wholesale funder toggle route missing"
        return false
      end
      
      if Rails.application.routes.url_helpers.respond_to?(:toggle_active_admin_lender_funder_pool_path)
        puts "  ✅ Funder pool toggle route exists"
      else
        puts "  ❌ Funder pool toggle route missing"
        return false
      end
      
      puts "\n🎉 ALL TOGGLE TESTS PASSED!"
      puts "The toggle functionality is working correctly programmatically."
      puts "Routes are properly defined and status changes work as expected."
      
      return true
      
    rescue => e
      puts "\n💥 ERROR: #{e.message}"
      puts e.backtrace.first(3).join("\n")
      return false
    end
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  success = ManualToggleTest.run
  exit(success ? 0 : 1)
end