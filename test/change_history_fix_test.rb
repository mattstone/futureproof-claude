#!/usr/bin/env ruby

# Change History Fix Test
# Tests the fix for undefined local variable 'action' error in change history partial

require_relative '../config/environment'

class ChangeHistoryFixTest
  def initialize
    @verification_passed = true
    @errors = []
    @test_mortgage = nil
    @test_lender = nil
  end

  def run_verification
    puts "\n🔧 CHANGE HISTORY FIX TEST"
    puts "=" * 60
    puts "Testing fixes for undefined local variable 'action' error:"
    puts "- MortgageLenderVersion.action_description method fixed"
    puts "- MortgageLender.action_description method removed"
    puts "- has_field_changes? and detailed_changes methods added"
    puts "- Mixed version types in @all_versions handled correctly"
    puts

    begin
      cleanup_test_data
      create_test_data
      test_mortgage_lender_version_methods
      test_mixed_version_types
      test_change_history_partial_compatibility
      cleanup_test_data
      
      if @verification_passed
        puts "\n✅ CHANGE HISTORY FIX TEST PASSED!"
        puts "The change history partial should now work without errors."
      else
        puts "\n❌ VERIFICATION FAILED!"
        puts "Issues found:"
        @errors.each { |error| puts "  - #{error}" }
        exit 1
      end
      
    rescue => e
      @verification_passed = false
      puts "\n💥 CRITICAL ERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  private

  def cleanup_test_data
    # Clean up any existing test data
    Mortgage.where("name LIKE 'Test Change History%'").destroy_all
    Lender.where("name LIKE 'Test Change History%'").destroy_all
  end

  def create_test_data
    puts "Phase 1: Creating test data for change history testing..."
    
    # Create test lender
    @test_lender = Lender.create!(
      name: "Test Change History Lender #{Time.current.to_i}",
      contact_email: "changehistory#{Time.current.to_i}@test.com",
      lender_type: :lender,
      country: "Australia"
    )
    
    # Create test mortgage
    @test_mortgage = Mortgage.create!(
      name: "Test Change History Mortgage #{Time.current.to_i}",
      mortgage_type: :principal_and_interest,
      lvr: 80.0
    )
    
    puts "  ✓ Created test lender and mortgage"
  end

  def test_mortgage_lender_version_methods
    puts "\nPhase 2: Testing MortgageLenderVersion methods..."
    
    # Create a mortgage lender to generate a version
    mortgage_lender = MortgageLender.create!(
      mortgage: @test_mortgage,
      lender: @test_lender,
      active: true
    )
    
    # Get the version that was created
    version = mortgage_lender.mortgage_lender_versions.first
    
    if version
      puts "  ✓ MortgageLenderVersion created successfully"
      
      # Test action_description method
      begin
        action_desc = version.action_description
        puts "  ✅ action_description method works: '#{action_desc}'"
      rescue => e
        @verification_passed = false
        @errors << "action_description method failed: #{e.message}"
      end
      
      # Test formatted_created_at method
      begin
        formatted_time = version.formatted_created_at
        puts "  ✅ formatted_created_at method works: '#{formatted_time}'"
      rescue => e
        @verification_passed = false
        @errors << "formatted_created_at method failed: #{e.message}"
      end
      
      # Test admin_user alias
      begin
        admin_user = version.admin_user
        puts "  ✅ admin_user alias works (user: #{admin_user ? admin_user.class.name : 'nil'})"
      rescue => e
        @verification_passed = false
        @errors << "admin_user alias failed: #{e.message}"
      end
      
      # Test has_field_changes? method
      begin
        has_changes = version.has_field_changes?
        puts "  ✅ has_field_changes? method works: #{has_changes}"
      rescue => e
        @verification_passed = false
        @errors << "has_field_changes? method failed: #{e.message}"
      end
      
      # Test detailed_changes method
      begin
        details = version.detailed_changes
        puts "  ✅ detailed_changes method works: #{details.is_a?(Array) ? details.length : 0} changes"
      rescue => e
        @verification_passed = false
        @errors << "detailed_changes method failed: #{e.message}"
      end
      
    else
      @verification_passed = false
      @errors << "No MortgageLenderVersion was created"
    end
  end

  def test_mixed_version_types
    puts "\nPhase 3: Testing mixed version types (like in @all_versions)..."
    
    # Simulate what the mortgage controller does
    mortgage_versions = @test_mortgage.mortgage_versions
    lender_versions = MortgageLenderVersion.joins(:mortgage_lender)
                                         .where(mortgage_lenders: { mortgage_id: @test_mortgage.id })
    
    # Combine them like the controller does
    all_versions = (mortgage_versions + lender_versions)
                     .sort_by(&:created_at)
                     .reverse
    
    puts "  ✓ Found #{mortgage_versions.count} mortgage versions"
    puts "  ✓ Found #{lender_versions.count} lender versions"
    puts "  ✓ Combined total: #{all_versions.count} versions"
    
    # Test that all versions have the required methods for the partial
    all_versions.each_with_index do |version, index|
      version_type = version.class.name
      
      begin
        # Test methods required by the change history partial
        admin_user = version.admin_user
        action_desc = version.action_description
        formatted_time = version.formatted_created_at
        has_changes = version.has_field_changes?
        details = version.detailed_changes
        
        puts "    ✅ Version #{index + 1} (#{version_type}): All methods work"
        
      rescue => e
        @verification_passed = false
        @errors << "Version #{index + 1} (#{version_type}) failed: #{e.message}"
      end
    end
  end

  def test_change_history_partial_compatibility
    puts "\nPhase 4: Testing change history partial compatibility..."
    
    # Simulate what happens in the view when rendering the partial
    mortgage_versions = @test_mortgage.mortgage_versions
    lender_versions = MortgageLenderVersion.joins(:mortgage_lender)
                                         .where(mortgage_lenders: { mortgage_id: @test_mortgage.id })
    
    all_versions = (mortgage_versions + lender_versions)
                     .sort_by(&:created_at)
                     .reverse
    
    # Test the specific line that was causing the error (line 14 in the partial)
    all_versions.each do |version|
      begin
        # This is what line 14 of the partial does:
        # <span class="change-action"><%= version.action_description %></span>
        action_description = version.action_description
        
        if action_description.is_a?(String) && action_description.length > 0
          puts "    ✅ version.action_description works: '#{action_description}'"
        else
          @verification_passed = false
          @errors << "action_description returned invalid value: #{action_description.inspect}"
        end
        
      rescue NoMethodError => e
        @verification_passed = false
        @errors << "NoMethodError in action_description: #{e.message}"
      rescue => e
        @verification_passed = false
        @errors << "Unexpected error in action_description: #{e.message}"
      end
    end
    
    # Test other partial requirements
    puts "  ✓ Testing other partial requirements..."
    
    partial_method_tests = [
      :admin_user,
      :formatted_created_at,
      :has_field_changes?,
      :detailed_changes
    ]
    
    all_versions.each do |version|
      partial_method_tests.each do |method|
        begin
          result = version.send(method)
          puts "    ✅ #{version.class.name}.#{method} works"
        rescue => e
          @verification_passed = false
          @errors << "#{version.class.name}.#{method} failed: #{e.message}"
        end
      end
    end
  end
end

# Run verification if script is executed directly
if __FILE__ == $0
  verification = ChangeHistoryFixTest.new
  verification.run_verification
end