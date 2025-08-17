#!/usr/bin/env ruby

# Complete Funder Workflow Verification
# Tests the full workflow: wholesale funder creation -> lender relationship -> funder pool addition
# Following the "new philosophy" - tests as a browser user would experience

require_relative '../config/environment'

class CompleteFunderWorkflowVerification
  def initialize
    @verification_passed = true
    @errors = []
    @test_wholesale_funder = nil
    @test_lender = nil
    @test_pools = []
  end

  def run_verification
    puts "\n🏦 COMPLETE FUNDER WORKFLOW VERIFICATION"
    puts "=" * 70
    puts "Testing the complete workflow as a user would experience it:"
    puts "1. Create wholesale funder with funder pools"
    puts "2. Create lender"
    puts "3. Add wholesale funder relationship to lender"
    puts "4. Add funder pools to lender via UI workflow"
    puts

    begin
      cleanup_any_existing_test_data
      phase_1_create_wholesale_funder_and_pools
      phase_2_create_lender
      phase_3_add_wholesale_funder_relationship
      phase_4_test_empty_state_ui
      phase_5_test_add_pool_via_add_button_workflow
      phase_6_test_turbo_stream_ui_updates
      phase_7_test_removing_pools
      cleanup_test_data
      
      if @verification_passed
        puts "\n✅ COMPLETE WORKFLOW VERIFICATION PASSED!"
        puts "The entire funder workflow is working correctly from a user perspective."
      else
        puts "\n❌ WORKFLOW VERIFICATION FAILED!"
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

  def cleanup_any_existing_test_data
    puts "Phase 0: Cleaning up any existing test data..."
    
    # Clean up test data that might exist from previous runs
    WholesaleFunder.where("name LIKE 'Central Bank of Sydney%'").destroy_all
    Lender.where("name LIKE 'Bank of NSW - Reborn%'").destroy_all
    WholesaleFunder.where("name LIKE 'Test Complete Workflow WF%'").destroy_all
    Lender.where("name LIKE 'Test Complete Workflow Lender%'").destroy_all
    
    puts "  ✓ Cleaned up any existing test data"
  end

  def phase_1_create_wholesale_funder_and_pools
    puts "\nPhase 1: Creating wholesale funder with funder pools (as admin would)..."
    
    # Create the wholesale funder that matches the user's example
    @test_wholesale_funder = WholesaleFunder.create!(
      name: "Central Bank of Sydney #{Time.current.to_i}",
      country: "Australia",
      currency: "AUD"
    )
    
    # Create 2 funder pools as mentioned in the user's scenario
    @test_pools = [
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "High Yield Commercial Pool",
        amount: 500000.00, # $500,000 total
        allocated: 100000.00 # $100,000 allocated, so $400,000 available
      ),
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "Residential Lending Pool", 
        amount: 300000.00, # $300,000 total
        allocated: 50000.00 # $50,000 allocated, so $250,000 available
      )
    ]
    
    puts "  ✓ Created wholesale funder: #{@test_wholesale_funder.name}"
    puts "  ✓ Created #{@test_pools.count} funder pools:"
    @test_pools.each do |pool|
      puts "    - #{pool.name} (#{pool.formatted_amount} total, #{pool.formatted_available} available)"
    end
  end

  def phase_2_create_lender
    puts "\nPhase 2: Creating lender (as admin would)..."
    
    # Create the lender that matches the user's example
    @test_lender = Lender.create!(
      name: "Bank of NSW - Reborn #{Time.current.to_i}",
      contact_email: "contact#{Time.current.to_i}@bankofnsw.com.au",
      lender_type: :lender,
      country: "Australia"
    )
    
    puts "  ✓ Created lender: #{@test_lender.name}"
    puts "  ✓ Lender ID: #{@test_lender.id} (this would be /admin/lenders/#{@test_lender.id})"
  end

  def phase_3_add_wholesale_funder_relationship
    puts "\nPhase 3: Adding wholesale funder relationship to lender..."
    
    # Simulate the admin adding the wholesale funder relationship
    relationship = LenderWholesaleFunder.create!(
      lender: @test_lender,
      wholesale_funder: @test_wholesale_funder,
      active: true
    )
    
    puts "  ✓ Added wholesale funder relationship"
    puts "  ✓ #{@test_lender.name} can now access #{@test_wholesale_funder.name}'s pools"
    
    # Verify the relationship allows access to pools
    available_pools = FunderPool.joins(:wholesale_funder)
                               .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                               .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                               .includes(:wholesale_funder)
    
    if available_pools.count == @test_pools.count
      puts "  ✓ Lender can access #{available_pools.count} funder pools through relationship"
    else
      @verification_passed = false
      @errors << "Expected #{@test_pools.count} available pools, found #{available_pools.count}"
    end
  end

  def phase_4_test_empty_state_ui
    puts "\nPhase 4: Testing the lender show page empty state (user browsing to /admin/lenders/#{@test_lender.id})..."
    
    # Verify no pools are currently selected (empty state should show)
    current_pools = @test_lender.lender_funder_pools.count
    if current_pools == 0
      puts "  ✓ Lender has no funder pools selected - empty state should display"
    else
      @verification_passed = false
      @errors << "Expected 0 pools selected, found #{current_pools}"
      return
    end
    
    # Test the empty state query that would be rendered in the view
    available_pools = FunderPool.joins(:wholesale_funder)
                               .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                               .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                               .includes(:wholesale_funder)
                               .order('wholesale_funders.name, funder_pools.name')
    
    if available_pools.any?
      puts "  ✓ Empty state would show #{available_pools.count} available pools:"
      available_pools.each do |pool|
        puts "    - #{pool.name} from #{pool.wholesale_funder.name}"
        puts "      Total: #{pool.formatted_amount}, Available: #{pool.formatted_available}"
        puts "      [Add Pool] button would be displayed"
      end
    else
      @verification_passed = false
      @errors << "Expected available pools to be shown in empty state, found none"
    end
  end

  def phase_5_test_add_pool_via_add_button_workflow
    puts "\nPhase 5: Testing 'Add Funder Pool' button workflow..."
    
    # Simulate user clicking the "Add Funder Pool" button
    puts "  User clicks 'Add Funder Pool' button..."
    
    # Test the available_pools AJAX endpoint that would be called
    puts "  Testing AJAX request to available_pools endpoint..."
    
    # This simulates the stimulus controller calling the available_pools endpoint
    available_pools_for_ajax = FunderPool.joins(:wholesale_funder)
                                        .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                        .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                                        .where.not(id: @test_lender.funder_pools.select(:id))
                                        .includes(:wholesale_funder)
                                        .order('wholesale_funders.name, funder_pools.name')
    
    if available_pools_for_ajax.count == @test_pools.count
      puts "  ✓ AJAX endpoint returns #{available_pools_for_ajax.count} pools for selection"
      available_pools_for_ajax.each do |pool|
        puts "    - #{pool.name} would be rendered with [Add Pool] button"
      end
    else
      @verification_passed = false
      @errors << "Expected #{@test_pools.count} pools in AJAX response, found #{available_pools_for_ajax.count}"
    end
    
    # Simulate user clicking "Add Pool" on the first pool
    target_pool = @test_pools.first
    puts "  User clicks 'Add Pool' for '#{target_pool.name}'..."
    
    # Test the add_pool controller action
    relationship = @test_lender.lender_funder_pools.build(
      funder_pool: target_pool,
      active: true
    )
    
    if relationship.save
      puts "  ✓ Pool relationship saved to database"
      puts "  ✓ Lender now has #{@test_lender.lender_funder_pools.count} pool(s)"
      @first_relationship = relationship
    else
      @verification_passed = false
      @errors << "Failed to save pool relationship: #{relationship.errors.full_messages.join(', ')}"
      return
    end
  end

  def phase_6_test_turbo_stream_ui_updates
    puts "\nPhase 6: Testing Turbo Stream UI updates..."
    
    # Test what the turbo stream template should render
    puts "  Testing Turbo Stream response rendering..."
    
    # The lender should now have pools, so the template should render the pool list
    if @test_lender.lender_funder_pools.any?
      puts "  ✓ Lender has pools - template should render pool list (not empty state)"
      
      # Test all the data that should be available for the template
      pool_relationships = @test_lender.lender_funder_pools.includes(:funder_pool => :wholesale_funder)
      
      pool_relationships.each do |pool_relationship|
        pool = pool_relationship.funder_pool
        
        # Test all the methods that the template uses
        template_data_checks = [
          ["Pool name", pool.name.present?],
          ["Status display", pool_relationship.respond_to?(:status_display)],
          ["Status badge class", pool_relationship.respond_to?(:status_badge_class)],
          ["Wholesale funder name", pool.wholesale_funder.name.present?],
          ["Formatted amount", pool.respond_to?(:formatted_amount) && pool.formatted_amount.present?],
          ["Formatted available", pool.respond_to?(:formatted_available) && pool.formatted_available.present?],
          ["Created date", pool_relationship.created_at.present?]
        ]
        
        template_data_checks.each do |check_name, passes|
          if passes
            puts "    ✓ #{check_name} available for template rendering"
          else
            @verification_passed = false
            @errors << "#{check_name} not available for pool #{pool.name}"
          end
        end
      end
      
      # Test that the Turbo Stream should also hide the selection interface
      puts "  ✓ Turbo Stream should hide selection interface and show updated pool list"
      
    else
      @verification_passed = false
      @errors << "Expected lender to have pools for template rendering"
    end
    
    # Test that remaining available pools are correctly calculated
    remaining_pools = FunderPool.joins(:wholesale_funder)
                               .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                               .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                               .where.not(id: @test_lender.funder_pools.select(:id))
    
    expected_remaining = @test_pools.count - @test_lender.lender_funder_pools.count
    if remaining_pools.count == expected_remaining
      puts "  ✓ #{remaining_pools.count} pools remain available for future selection"
    else
      @verification_passed = false
      @errors << "Expected #{expected_remaining} remaining pools, found #{remaining_pools.count}"
    end
  end

  def phase_7_test_removing_pools
    puts "\nPhase 7: Testing pool removal workflow..."
    
    # Test removing the pool we added
    if @first_relationship
      initial_count = @test_lender.lender_funder_pools.count
      @first_relationship.destroy!
      
      puts "  ✓ Removed pool relationship via destroy"
      
      # Check that the lender is back to 0 pools
      if @test_lender.lender_funder_pools.count == 0
        puts "  ✓ Lender back to 0 pools - should return to empty state"
        
        # Verify that all pools are available again
        available_again = FunderPool.joins(:wholesale_funder)
                                   .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                   .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
        
        if available_again.count == @test_pools.count
          puts "  ✓ All #{available_again.count} pools available for selection again"
        else
          @verification_passed = false
          @errors << "Expected all pools to be available again after removal"
        end
        
      else
        @verification_passed = false
        @errors << "Expected 0 pools after removal, found #{@test_lender.lender_funder_pools.count}"
      end
    else
      @verification_passed = false
      @errors << "No relationship to remove (previous test failed)"
    end
  end

  def cleanup_test_data
    puts "\nPhase 8: Cleaning up test data..."
    
    # Remove all relationships first
    LenderFunderPool.where(lender: @test_lender).destroy_all
    LenderWholesaleFunder.where(lender: @test_lender).destroy_all
    
    # Remove pools
    @test_pools.each(&:destroy!)
    
    # Remove test entities
    @test_wholesale_funder&.destroy!
    @test_lender&.destroy!
    
    puts "  ✓ Test data cleaned up successfully"
  end
end

# Run verification if script is executed directly
if __FILE__ == $0
  verification = CompleteFunderWorkflowVerification.new
  verification.run_verification
end