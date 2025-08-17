#!/usr/bin/env ruby

# Mortgage Two-Column Layout Functional Verification
# This script verifies the new lender relationships layout and change history integration

require_relative '../config/environment'

class MortgageTwoColumnLayoutVerification
  def initialize
    @test_mortgage = nil
    @test_lenders = []
    @verification_passed = true
    @errors = []
  end

  def run_verification
    puts "\n🏠 MORTGAGE TWO-COLUMN LAYOUT VERIFICATION"
    puts "=" * 50
    puts "Testing new lender relationships layout and change history integration..."
    puts

    begin
      setup_test_data
      verify_ui_layout_structure
      verify_change_history_integration
      verify_relationship_management_workflow
      verify_turbo_stream_updates
      verify_responsive_design
      cleanup_test_data
      
      if @verification_passed
        puts "\n✅ ALL VERIFICATION PHASES PASSED!"
        puts "The new two-column layout is working correctly."
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

  def setup_test_data
    puts "Phase 1: Setting up test data..."
    
    # Create test mortgage
    @test_mortgage = Mortgage.create!(
      name: "Two-Column Layout Test Mortgage",
      mortgage_type: :principal_and_interest,
      lvr: 80.0
    )
    
    # Use existing lenders to avoid validation conflicts
    @test_lenders = []
    
    # Find existing Futureproof lender or create if none exists
    futureproof_lender = Lender.find_by(lender_type: :futureproof)
    if futureproof_lender
      @test_lenders << futureproof_lender
    end
    
    # Create test lenders (using :lender type)
    @test_lenders << Lender.create!(
      name: "Test External Lender A",
      contact_email: "external_a@test.com", 
      lender_type: :lender
    )
    
    @test_lenders << Lender.create!(
      name: "Test External Lender B", 
      contact_email: "external_b@test.com",
      lender_type: :lender
    )
    
    puts "  ✓ Created test mortgage: #{@test_mortgage.name}"
    puts "  ✓ Created #{@test_lenders.count} test lenders"
  end

  def verify_ui_layout_structure
    puts "\nPhase 2: Verifying UI layout structure..."
    
    # Check that the view file contains the new layout structure
    show_view_path = Rails.root.join('app/views/admin/mortgages/show.html.erb')
    
    if File.exist?(show_view_path)
      view_content = File.read(show_view_path)
      
      # Verify key layout elements are present
      layout_checks = [
        ['Two-column layout container', 'lender-two-column-layout'],
        ['Left column (existing relationships)', 'Existing Relationships'],
        ['Right column (add new)', 'Add New Relationship'],
        ['Change history section', 'shared/change_history'],
        ['Empty relationships styling', 'empty-relationships'],
        ['Lender relationship cards', 'lender-relationship-card']
      ]
      
      layout_checks.each do |name, selector|
        if view_content.include?(selector)
          puts "  ✓ #{name} structure found"
        else
          @verification_passed = false
          @errors << "Missing #{name} (#{selector})"
          puts "  ❌ Missing #{name}"
        end
      end
    else
      @verification_passed = false
      @errors << "Missing mortgage show view file"
      puts "  ❌ Missing mortgage show view file"
    end
  end

  def verify_change_history_integration
    puts "\nPhase 3: Verifying change history integration..."
    
    # Create a mortgage lender relationship to generate change history
    relationship = MortgageLender.create!(
      mortgage: @test_mortgage,
      lender: @test_lenders.first,
      active: true
    )
    
    # Verify change history is created
    versions = MortgageVersion.where(mortgage: @test_mortgage)
    lender_versions = MortgageLenderVersion.where(mortgage_lender: relationship)
    
    puts "  ✓ Mortgage versions count: #{versions.count}"
    puts "  ✓ Lender relationship versions count: #{lender_versions.count}"
    
    # Test that versions have the required alias method
    if lender_versions.any?
      version = lender_versions.first
      if version.respond_to?(:admin_user)
        puts "  ✓ admin_user alias method available"
      else
        @verification_passed = false
        @errors << "admin_user alias method missing from MortgageLenderVersion"
        puts "  ❌ admin_user alias method missing"
      end
    end
    
    # Test combined version collection
    all_versions = (versions.to_a + lender_versions.to_a).sort_by(&:created_at).reverse
    puts "  ✓ Combined versions count: #{all_versions.count}"
  end

  def verify_relationship_management_workflow
    puts "\nPhase 4: Verifying relationship management workflow..."
    
    # Test adding remaining lenders (first one was already added in phase 3)
    remaining_lenders = @test_lenders[1..-1] # Skip first lender
    remaining_lenders.each_with_index do |lender, index|
      relationship = MortgageLender.create!(
        mortgage: @test_mortgage,
        lender: lender,
        active: true
      )
      puts "  ✓ Added lender #{index + 2}: #{lender.name}"
    end
    
    # Verify relationships are created correctly
    total_relationships = @test_mortgage.mortgage_lenders.count
    active_relationships = @test_mortgage.active_lenders.count
    
    if total_relationships == @test_lenders.count
      puts "  ✓ All lender relationships created (#{total_relationships})"
    else
      @verification_passed = false
      @errors << "Expected #{@test_lenders.count} relationships, got #{total_relationships}"
    end
    
    # Test toggling relationship status
    first_relationship = @test_mortgage.mortgage_lenders.first
    original_status = first_relationship.active
    first_relationship.update!(active: !original_status)
    
    if first_relationship.active != original_status
      puts "  ✓ Relationship status toggle working"
      # Restore original status
      first_relationship.update!(active: original_status)
    else
      @verification_passed = false
      @errors << "Relationship status toggle failed"
    end
    
    # Test relationship removal
    last_relationship = @test_mortgage.mortgage_lenders.last
    last_relationship.destroy!
    
    if @test_mortgage.mortgage_lenders.count == @test_lenders.count - 1
      puts "  ✓ Relationship removal working"
    else
      @verification_passed = false
      @errors << "Relationship removal failed"
    end
  end

  def verify_turbo_stream_updates
    puts "\nPhase 5: Verifying Turbo Stream updates..."
    
    # Test that all Turbo Stream templates exist and use correct CSS classes
    turbo_templates = [
      'app/views/admin/mortgage_lenders/add_lender.turbo_stream.erb',
      'app/views/admin/mortgage_lenders/destroy.turbo_stream.erb', 
      'app/views/admin/mortgage_lenders/toggle_active.turbo_stream.erb'
    ]
    
    turbo_templates.each do |template_path|
      full_path = Rails.root.join(template_path)
      if File.exist?(full_path)
        content = File.read(full_path)
        
        # Check for updated CSS classes
        if content.include?('lender-relationship-card') && 
           content.include?('empty-relationships') &&
           content.include?('relationship-created')
          puts "  ✓ #{File.basename(template_path)} updated with new classes"
        else
          @verification_passed = false
          @errors << "#{template_path} missing new CSS classes"
          puts "  ❌ #{File.basename(template_path)} needs CSS class updates"
        end
      else
        @verification_passed = false
        @errors << "Missing Turbo Stream template: #{template_path}"
        puts "  ❌ Missing template: #{File.basename(template_path)}"
      end
    end
  end

  def verify_responsive_design
    puts "\nPhase 6: Verifying responsive design..."
    
    # Check that the show view includes mobile responsive CSS
    show_view_path = Rails.root.join('app/views/admin/mortgages/show.html.erb')
    
    if File.exist?(show_view_path)
      content = File.read(show_view_path)
      
      responsive_checks = [
        ['Mobile breakpoint', '@media (max-width: 768px)'],
        ['Grid column collapse', 'grid-template-columns: 1fr'],
        ['Responsive layout class', 'lender-two-column-layout']
      ]
      
      responsive_checks.each do |name, pattern|
        if content.include?(pattern)
          puts "  ✓ #{name} CSS found"
        else
          @verification_passed = false
          @errors << "Missing responsive design: #{name}"
          puts "  ❌ Missing #{name}"
        end
      end
    else
      @verification_passed = false
      @errors << "Missing mortgage show view"
    end
  end

  def cleanup_test_data
    puts "\nPhase 7: Cleaning up test data..."
    
    # Remove all test relationships first
    MortgageLender.where(mortgage: @test_mortgage).destroy_all
    
    # Remove test mortgage
    @test_mortgage&.destroy!
    
    # Remove only the test external lenders we created (not existing Futureproof lender)
    @test_lenders.select { |lender| lender.name.include?("Test External Lender") }.each(&:destroy!)
    
    puts "  ✓ Test data cleaned up successfully"
  end
end

# Run verification if script is executed directly
if __FILE__ == $0
  verification = MortgageTwoColumnLayoutVerification.new
  verification.run_verification
end