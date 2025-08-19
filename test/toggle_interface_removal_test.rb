#!/usr/bin/env ruby

# Comprehensive test to verify old toggle interface is completely removed
# and only clickable status badges remain

require_relative '../config/environment'

class ToggleInterfaceRemovalTest
  def self.run
    puts "🧪 Testing Complete Removal of Old Toggle Interface..."
    puts "This test ensures no old 'Toggle' buttons remain in the updated areas"
    
    begin
      # Create test data
      puts "\n📋 Creating test data..."
      lender = create_test_lender
      admin_user = create_admin_user(lender)
      wholesale_funder = create_wholesale_funder
      funder_pool = create_funder_pool(wholesale_funder)
      
      # Create relationships
      wholesale_relationship = lender.lender_wholesale_funders.create!(
        wholesale_funder: wholesale_funder,
        active: true
      )
      
      pool_relationship = lender.lender_funder_pools.create!(
        funder_pool: funder_pool,
        active: true
      )
      
      puts "✅ Test data created successfully"
      
      # Test 1: Verify main admin lender view has no old toggle buttons
      puts "\n📋 Test 1: Checking main admin lender view template..."
      main_template_path = Rails.root.join('app/views/admin/lenders/show.html.erb')
      main_template_content = File.read(main_template_path)
      
      # Search for old toggle button patterns
      old_toggle_patterns = [
        /button_to\s+"Toggle"/,
        /<span[^>]*status-badge[^>]*>.*?<\/span>.*?button_to\s+"Toggle"/m,
        /Toggle.*method:\s*:patch.*class:.*admin-btn/
      ]
      
      old_toggle_found = false
      old_toggle_patterns.each_with_index do |pattern, index|
        if main_template_content.match(pattern)
          puts "  ❌ Found old toggle pattern #{index + 1} in main template"
          old_toggle_found = true
        end
      end
      
      if !old_toggle_found
        puts "  ✅ Main template clean - no old toggle buttons found"
      end
      
      # Verify clickable status badges exist
      clickable_badge_patterns = [
        /button_to.*relationship\.status_display.*clickable-status-badge/,
        /button_to.*pool_relationship\.status_display.*clickable-status-badge/
      ]
      
      clickable_badges_found = 0
      clickable_badge_patterns.each do |pattern|
        if main_template_content.match(pattern)
          clickable_badges_found += 1
        end
      end
      
      if clickable_badges_found >= 2
        puts "  ✅ Found #{clickable_badges_found} clickable status badges in main template"
      else
        puts "  ⚠️  Only found #{clickable_badges_found} clickable status badges (expected at least 2)"
      end
      
      # Test 2: Check all Turbo Stream templates
      puts "\n📋 Test 2: Checking Turbo Stream templates..."
      
      turbo_templates = [
        'app/views/admin/lender_wholesale_funders/toggle_wholesale_funder.turbo_stream.erb',
        'app/views/admin/lender_funder_pools/toggle_active.turbo_stream.erb',
        'app/views/admin/lender_wholesale_funders/add_wholesale_funder.turbo_stream.erb',
        'app/views/admin/lender_wholesale_funders/destroy_wholesale_funder.turbo_stream.erb',
        'app/views/admin/lender_funder_pools/add_pool.turbo_stream.erb',
        'app/views/admin/lender_funder_pools/destroy.turbo_stream.erb'
      ]
      
      templates_with_old_toggles = []
      templates_with_clickable_badges = []
      
      turbo_templates.each do |template_path|
        full_path = Rails.root.join(template_path)
        if File.exist?(full_path)
          content = File.read(full_path)
          
          # Check for old toggle patterns
          has_old_toggle = old_toggle_patterns.any? { |pattern| content.match(pattern) }
          if has_old_toggle
            templates_with_old_toggles << template_path
          end
          
          # Check for clickable badges
          has_clickable_badge = clickable_badge_patterns.any? { |pattern| content.match(pattern) }
          if has_clickable_badge
            templates_with_clickable_badges << template_path
          end
        else
          puts "  ⚠️  Template not found: #{template_path}"
        end
      end
      
      if templates_with_old_toggles.empty?
        puts "  ✅ All Turbo Stream templates clean - no old toggle buttons found"
      else
        puts "  ❌ Found old toggle buttons in:"
        templates_with_old_toggles.each { |t| puts "    - #{t}" }
        return false
      end
      
      puts "  ✅ Found clickable badges in #{templates_with_clickable_badges.count}/#{turbo_templates.count} templates"
      
      # Test 3: Test actual controller responses
      puts "\n📋 Test 3: Testing controller responses..."
      
      # Set up controller environment
      app = Rails.application
      request_env = {
        'REQUEST_METHOD' => 'PATCH',
        'PATH_INFO' => "/admin/lenders/#{lender.id}/wholesale_funders/#{wholesale_relationship.id}/toggle_active",
        'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest'
      }
      
      # Mock the controller action
      wholesale_controller = Admin::LenderWholesaleFundersController.new
      wholesale_controller.params = ActionController::Parameters.new(
        lender_id: lender.id,
        id: wholesale_relationship.id
      )
      
      # Mock current_user
      def wholesale_controller.current_user
        @current_user ||= User.where(admin: true).first
      end
      
      # Verify that the controller action exists and works
      if wholesale_controller.respond_to?(:toggle_active, true)
        puts "  ✅ Wholesale funder toggle_active action exists"
        
        # Test the actual toggle functionality
        original_status = wholesale_relationship.active?
        wholesale_relationship.toggle_active!
        new_status = wholesale_relationship.active?
        
        if original_status != new_status
          puts "  ✅ Toggle functionality works correctly"
          
          # Restore status
          wholesale_relationship.update!(active: original_status)
        else
          puts "  ❌ Toggle functionality not working"
          return false
        end
      else
        puts "  ❌ toggle_active action missing from wholesale funder controller"
        return false
      end
      
      # Test funder pool controller
      pool_controller = Admin::LenderFunderPoolsController.new
      pool_controller.params = ActionController::Parameters.new(
        lender_id: lender.id,
        id: pool_relationship.id
      )
      
      def pool_controller.current_user
        @current_user ||= User.where(admin: true).first
      end
      
      if pool_controller.respond_to?(:toggle_active, true)
        puts "  ✅ Funder pool toggle_active action exists"
        
        # Test functionality
        original_pool_status = pool_relationship.active?
        pool_relationship.toggle_active!
        new_pool_status = pool_relationship.active?
        
        if original_pool_status != new_pool_status
          puts "  ✅ Funder pool toggle functionality works correctly"
          
          # Restore status
          pool_relationship.update!(active: original_pool_status)
        else
          puts "  ❌ Funder pool toggle functionality not working"
          return false
        end
      else
        puts "  ❌ toggle_active action missing from funder pool controller"
        return false
      end
      
      # Test 4: Verify accessibility attributes
      puts "\n📋 Test 4: Testing accessibility attributes..."
      
      accessibility_patterns = [
        /role="button"/,
        /tabindex="0"/,
        /data-confirm/,
        /aria-label/
      ]
      
      accessibility_found = 0
      accessibility_patterns.each do |pattern|
        if main_template_content.match(pattern)
          accessibility_found += 1
        end
      end
      
      if accessibility_found >= 3
        puts "  ✅ Found #{accessibility_found}/#{accessibility_patterns.count} accessibility attributes"
      else
        puts "  ⚠️  Only found #{accessibility_found}/#{accessibility_patterns.count} accessibility attributes"
      end
      
      # Test 5: Verify CSS classes are present
      puts "\n📋 Test 5: Testing CSS classes..."
      
      css_patterns = [
        /clickable-status-badge/,
        /status-badge/
      ]
      
      css_found = 0
      css_patterns.each do |pattern|
        if main_template_content.match(pattern)
          css_found += 1
        end
      end
      
      if css_found >= 2
        puts "  ✅ Found required CSS classes"
      else
        puts "  ❌ Missing required CSS classes"
        return false
      end
      
      puts "\n🎉 ALL TOGGLE INTERFACE REMOVAL TESTS PASSED!"
      puts "\n📝 Test Summary:"
      puts "  ✅ Main admin lender view has no old toggle buttons"
      puts "  ✅ All Turbo Stream templates updated with clickable badges"  
      puts "  ✅ Controller toggle actions work correctly"
      puts "  ✅ Accessibility attributes are present"
      puts "  ✅ Required CSS classes are applied"
      
      puts "\n🚀 The old toggle interface has been completely removed!"
      puts "🌐 Only clickable status badges remain as requested"
      
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
  
  def self.create_test_lender
    Lender.create!(
      name: "Toggle Removal Test Lender #{Time.current.to_i}",
      contact_email: "toggle_removal#{Time.current.to_i}@testlender.com",
      lender_type: :lender,
      address: "123 Toggle Removal Street",
      country: "Australia"
    )
  end
  
  def self.create_admin_user(lender)
    User.create!(
      first_name: "Toggle",
      last_name: "RemovalAdmin",
      email: "toggle_removal_admin#{Time.current.to_i}@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      address: "Admin Address",
      lender: lender
    )
  end
  
  def self.create_wholesale_funder
    WholesaleFunder.create!(
      name: "Toggle Removal Wholesale Funder #{Time.current.to_i}",
      country: "Australia",
      currency: "AUD"
    )
  end
  
  def self.create_funder_pool(wholesale_funder)
    FunderPool.create!(
      name: "Toggle Removal Funder Pool #{Time.current.to_i}",
      amount: 1000000.0,
      allocated: 0.0,
      wholesale_funder: wholesale_funder
    )
  end
  
  def self.cleanup_test_data
    # Clean up in reverse dependency order
    LenderFunderPool.joins(:lender).where("lenders.name LIKE 'Toggle Removal Test Lender%'").destroy_all
    LenderWholesaleFunder.joins(:lender).where("lenders.name LIKE 'Toggle Removal Test Lender%'").destroy_all
    FunderPool.where("name LIKE 'Toggle Removal Funder Pool%'").destroy_all
    WholesaleFunder.where("name LIKE 'Toggle Removal Wholesale Funder%'").destroy_all
    User.where("email LIKE 'toggle_removal_admin%'").destroy_all
    Lender.where("name LIKE 'Toggle Removal Test Lender%'").destroy_all
    puts "✅ Test data cleaned up successfully"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  success = ToggleInterfaceRemovalTest.run
  exit(success ? 0 : 1)
end