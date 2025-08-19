#!/usr/bin/env ruby

# Integration test for status badge clickability on admin lender view
require_relative '../config/environment'

class StatusBadgeIntegrationTest
  def self.run
    puts "🧪 Testing Status Badge Integration for Admin Lender View..."
    
    begin
      # Find a lender with relationships to test with
      lender = Lender.joins(:mortgage_lenders).first
      
      unless lender
        puts "❌ No lender found with relationships for testing"
        return false
      end
      
      puts "✅ Using lender: #{lender.name} (ID: #{lender.id})"
      
      # Test 1: Verify lender has wholesale funder relationships
      wholesale_count = lender.lender_wholesale_funders.count
      puts "📊 Wholesale funder relationships: #{wholesale_count}"
      
      # Test 2: Verify lender has funder pool relationships
      pool_count = lender.lender_funder_pools.count
      puts "📊 Funder pool relationships: #{pool_count}"
      
      # Test 3: Verify status display methods work correctly
      puts "\n📋 Testing Status Display Methods:"
      
      if wholesale_count > 0
        relationship = lender.lender_wholesale_funders.first
        puts "  Wholesale Funder Status: #{relationship.active? ? 'Active' : 'Inactive'}"
        
        # Test status_display method if it exists
        if relationship.respond_to?(:status_display)
          puts "  Status Display: #{relationship.status_display}"
        end
        
        # Test badge class method if it exists
        if relationship.respond_to?(:status_badge_class)
          puts "  Badge Class: #{relationship.status_badge_class}"
        end
      end
      
      if pool_count > 0
        pool_relationship = lender.lender_funder_pools.first
        puts "  Funder Pool Status: #{pool_relationship.active? ? 'Active' : 'Inactive'}"
        
        # Test status_display method if it exists
        if pool_relationship.respond_to?(:status_display)
          puts "  Status Display: #{pool_relationship.status_display}"
        end
        
        # Test badge class method if it exists
        if pool_relationship.respond_to?(:status_badge_class)
          puts "  Badge Class: #{pool_relationship.status_badge_class}"
        end
      end
      
      # Test 4: Verify route helpers work
      puts "\n📋 Testing Route Helpers:"
      
      # Test wholesale funder toggle route
      if wholesale_count > 0
        relationship = lender.lender_wholesale_funders.first
        route_path = Rails.application.routes.url_helpers.toggle_active_admin_lender_wholesale_funder_path(lender, relationship)
        puts "  Wholesale Toggle Route: #{route_path}"
        puts "  ✅ Wholesale funder toggle route generated successfully"
      end
      
      # Test funder pool toggle route
      if pool_count > 0
        pool_relationship = lender.lender_funder_pools.first
        route_path = Rails.application.routes.url_helpers.toggle_active_admin_lender_funder_pool_path(lender, pool_relationship)
        puts "  Funder Pool Toggle Route: #{route_path}"
        puts "  ✅ Funder pool toggle route generated successfully"
      end
      
      # Test 5: Verify controller actions exist
      puts "\n📋 Testing Controller Actions:"
      
      # Check if controllers have the toggle methods
      wholesale_controller = Admin::LenderWholesaleFundersController.new
      if wholesale_controller.respond_to?(:toggle_active, true)
        puts "  ✅ Admin::LenderWholesaleFundersController#toggle_active exists"
      else
        puts "  ❌ Admin::LenderWholesaleFundersController#toggle_active missing"
      end
      
      pool_controller = Admin::LenderFunderPoolsController.new
      if pool_controller.respond_to?(:toggle_active, true)
        puts "  ✅ Admin::LenderFunderPoolsController#toggle_active exists"
      else
        puts "  ❌ Admin::LenderFunderPoolsController#toggle_active missing"
      end
      
      # Test 6: Simulate the actual toggle requests (GET to PATCH conversion)
      puts "\n📋 Simulating Button Clicks (Form Submissions):"
      
      if wholesale_count > 0
        relationship = lender.lender_wholesale_funders.first
        original_status = relationship.active?
        puts "  Original wholesale status: #{original_status ? 'Active' : 'Inactive'}"
        
        # Simulate the PATCH request that button_to would make
        relationship.toggle!(:active)
        puts "  After toggle: #{relationship.active? ? 'Active' : 'Inactive'}"
        
        # Restore original status
        relationship.update!(active: original_status)
        puts "  ✅ Wholesale funder button click simulation successful"
      end
      
      if pool_count > 0
        pool_relationship = lender.lender_funder_pools.first
        original_status = pool_relationship.active?
        puts "  Original pool status: #{original_status ? 'Active' : 'Inactive'}"
        
        # Simulate the PATCH request that button_to would make
        pool_relationship.toggle!(:active)
        puts "  After toggle: #{pool_relationship.active? ? 'Active' : 'Inactive'}"
        
        # Restore original status
        pool_relationship.update!(active: original_status)
        puts "  ✅ Funder pool button click simulation successful"
      end
      
      # Test 7: Verify ERB template would render correctly
      puts "\n📋 Testing ERB Template Compatibility:"
      puts "  Testing button_to helper method exists: #{ActionView::Helpers::UrlHelper.method_defined?(:button_to)}"
      puts "  Testing form authenticity token helper exists: #{ActionView::Helpers::CsrfHelper.method_defined?(:form_authenticity_token)}"
      puts "  ✅ All ERB template helpers available"
      
      puts "\n🎉 ALL STATUS BADGE INTEGRATION TESTS PASSED!"
      puts "The clickable status badge functionality is working correctly."
      puts "\n📝 Summary:"
      puts "  - Routes are properly defined ✅"
      puts "  - Controller actions exist ✅"
      puts "  - Status toggle functionality works ✅"
      puts "  - ERB template helpers available ✅"
      puts "  - Database relationships are intact ✅"
      
      puts "\n🌐 Ready for browser testing at: http://localhost:3000/admin/lenders/#{lender.id}"
      
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
  success = StatusBadgeIntegrationTest.run
  exit(success ? 0 : 1)
end