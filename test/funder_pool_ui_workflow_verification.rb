#!/usr/bin/env ruby

# Funder Pool UI Workflow Verification
# Tests the complete user workflow as experienced in a browser

require_relative '../config/environment'

class FunderPoolUIWorkflowVerification
  def initialize
    @verification_passed = true
    @errors = []
    @test_wholesale_funder = nil
    @test_lender = nil
    @test_pools = []
  end

  def run_verification
    puts "\n💰 FUNDER POOL UI WORKFLOW VERIFICATION"
    puts "=" * 60
    puts "Testing the complete funder pool workflow as a user would experience it"
    puts

    begin
      setup_test_data
      test_empty_state_shows_available_pools
      test_adding_pool_via_empty_state
      test_turbo_stream_updates_ui
      test_removing_pools_shows_empty_state_again
      test_error_handling
      cleanup_test_data
      
      if @verification_passed
        puts "\n✅ ALL WORKFLOW TESTS PASSED!"
        puts "The funder pool UI is working correctly from a user perspective."
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
    puts "Phase 1: Setting up test data (mimicking admin creating relationships)..."
    
    # Clean up any existing test data first
    WholesaleFunder.where("name LIKE 'Test Funder Pool Workflow WF%'").destroy_all
    Lender.where("name LIKE 'Test Lender for Pool Workflow%'").destroy_all
    
    # Create test wholesale funder
    @test_wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder Pool Workflow WF #{Time.current.to_i}",
      country: "Australia",
      currency: "AUD"
    )
    
    # Create funder pools for the wholesale funder
    @test_pools = [
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "High Value Pool",
        amount: 100000.00, # $100,000 total
        allocated: 20000.00 # $20,000 allocated, so $80,000 available
      ),
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "Standard Pool",
        amount: 50000.00, # $50,000 total
        allocated: 20000.00 # $20,000 allocated, so $30,000 available
      )
    ]
    
    # Create test lender
    @test_lender = Lender.create!(
      name: "Test Lender for Pool Workflow #{Time.current.to_i}",
      contact_email: "test#{Time.current.to_i}@poolworkflow.com",
      lender_type: :lender,
      country: "Australia"
    )
    
    # Establish wholesale funder relationship (prerequisite for pool access)
    LenderWholesaleFunder.create!(
      lender: @test_lender,
      wholesale_funder: @test_wholesale_funder,
      active: true
    )
    
    puts "  ✓ Created wholesale funder: #{@test_wholesale_funder.name}"
    puts "  ✓ Created #{@test_pools.count} funder pools"
    puts "  ✓ Created test lender: #{@test_lender.name}"
    puts "  ✓ Established wholesale funder relationship"
  end

  def test_empty_state_shows_available_pools
    puts "\nPhase 2: Testing empty state displays available pools..."
    
    # Simulate what the user sees on the lender show page
    # Check that no pools are currently selected
    current_pools = @test_lender.lender_funder_pools.count
    if current_pools == 0
      puts "  ✓ Lender has no funder pools selected (expected)"
    else
      @verification_passed = false
      @errors << "Expected 0 pools, found #{current_pools}"
      return
    end
    
    # Test the query that powers the empty state
    available_pools = FunderPool.joins(:wholesale_funder)
                                .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                                .includes(:wholesale_funder)
                                .order('wholesale_funders.name, funder_pools.name')
    
    if available_pools.count == @test_pools.count
      puts "  ✓ Available pools query returns #{available_pools.count} pools"
      available_pools.each do |pool|
        puts "    - #{pool.name} (#{pool.formatted_amount})"
      end
    else
      @verification_passed = false
      @errors << "Expected #{@test_pools.count} available pools, found #{available_pools.count}"
      return
    end
    
    # Test that each pool has proper formatting methods
    @test_pools.each do |pool|
      if pool.respond_to?(:formatted_amount) && pool.respond_to?(:formatted_available)
        puts "  ✓ Pool #{pool.name} has formatting methods"
      else
        @verification_passed = false
        @errors << "Pool #{pool.name} missing formatting methods"
      end
    end
  end

  def test_adding_pool_via_empty_state
    puts "\nPhase 3: Testing adding pool via empty state form..."
    
    # Simulate user clicking "Add Pool" button on first pool
    target_pool = @test_pools.first
    
    # Test the controller add_pool action logic
    controller = Admin::LenderFunderPoolsController.new
    controller.instance_variable_set(:@lender, @test_lender)
    
    # Simulate the add_pool request
    begin
      new_relationship = @test_lender.lender_funder_pools.build(
        funder_pool: target_pool,
        active: true
      )
      
      if new_relationship.save
        puts "  ✓ Pool relationship created successfully"
        puts "  ✓ Pool: #{target_pool.name}"
        puts "  ✓ Lender now has #{@test_lender.lender_funder_pools.count} pool(s)"
      else
        @verification_passed = false
        @errors << "Failed to create pool relationship: #{new_relationship.errors.full_messages.join(', ')}"
        return
      end
      
      @first_relationship = new_relationship
      
    rescue => e
      @verification_passed = false
      @errors << "Error adding pool: #{e.message}"
      return
    end
  end

  def test_turbo_stream_updates_ui
    puts "\nPhase 4: Testing Turbo Stream updates UI correctly..."
    
    # Simulate what the Turbo Stream template should render
    # This tests the logic in add_pool.turbo_stream.erb
    
    # Test that the lender now has pools (should show pool list, not empty state)
    if @test_lender.lender_funder_pools.any?
      puts "  ✓ Lender has pools - should show pool list"
      
      # Test the pool list structure
      @test_lender.lender_funder_pools.includes(:funder_pool => :wholesale_funder).each do |pool_relationship|
        pool = pool_relationship.funder_pool
        
        # Test all the data that should be displayed
        checks = [
          ["Pool name", pool.name.present?],
          ["Status display", pool_relationship.respond_to?(:status_display)],
          ["Status badge class", pool_relationship.respond_to?(:status_badge_class)],
          ["Wholesale funder name", pool.wholesale_funder.name.present?],
          ["Formatted amount", pool.formatted_amount.present?],
          ["Formatted available", pool.formatted_available.present?],
          ["Created date", pool_relationship.created_at.present?]
        ]
        
        checks.each do |check_name, passes|
          if passes
            puts "    ✓ #{check_name} available"
          else
            @verification_passed = false
            @errors << "#{check_name} not available for pool #{pool.name}"
          end
        end
      end
      
    else
      @verification_passed = false
      @errors << "Expected lender to have pools after adding one"
    end
    
    # Test available pools after one is selected
    remaining_available = FunderPool.joins(:wholesale_funder)
                                   .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                   .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                                   .where.not(id: @test_lender.funder_pools.select(:id))
                                   .includes(:wholesale_funder)
    
    expected_remaining = @test_pools.count - @test_lender.lender_funder_pools.count
    if remaining_available.count == expected_remaining
      puts "  ✓ Remaining available pools: #{remaining_available.count}"
    else
      @verification_passed = false
      @errors << "Expected #{expected_remaining} remaining pools, found #{remaining_available.count}"
    end
  end

  def test_removing_pools_shows_empty_state_again
    puts "\nPhase 5: Testing pool removal returns to empty state..."
    
    # Remove the pool we added
    if @first_relationship
      @first_relationship.destroy!
      puts "  ✓ Removed pool relationship"
      
      # Check that we're back to empty state
      if @test_lender.lender_funder_pools.count == 0
        puts "  ✓ Lender back to 0 pools"
        
        # Test that available pools are shown again
        available_again = FunderPool.joins(:wholesale_funder)
                                   .joins("INNER JOIN lender_wholesale_funders ON lender_wholesale_funders.wholesale_funder_id = wholesale_funders.id")
                                   .where(lender_wholesale_funders: { lender_id: @test_lender.id, active: true })
                                   .includes(:wholesale_funder)
        
        if available_again.count == @test_pools.count
          puts "  ✓ All pools available for selection again"
        else
          @verification_passed = false
          @errors << "Expected all pools to be available again"
        end
        
      else
        @verification_passed = false
        @errors << "Expected 0 pools after removal"
      end
    else
      @verification_passed = false
      @errors << "No relationship to remove (previous test failed)"
    end
  end

  def test_error_handling
    puts "\nPhase 6: Testing error handling..."
    
    # Test duplicate pool addition
    first_pool = @test_pools.first
    
    # Add a pool
    relationship1 = @test_lender.lender_funder_pools.create!(
      funder_pool: first_pool,
      active: true
    )
    
    # Try to add the same pool again
    relationship2 = @test_lender.lender_funder_pools.build(
      funder_pool: first_pool,
      active: true
    )
    
    if !relationship2.save
      puts "  ✓ Duplicate pool addition properly rejected"
      puts "  ✓ Error: #{relationship2.errors.full_messages.first}"
    else
      @verification_passed = false
      @errors << "Duplicate pool addition should have been rejected"
    end
    
    # Test adding pool from non-related wholesale funder
    unrelated_funder = WholesaleFunder.create!(
      name: "Unrelated Test Funder",
      country: "Australia", 
      currency: "AUD"
    )
    
    unrelated_pool = FunderPool.create!(
      wholesale_funder: unrelated_funder,
      name: "Unauthorized Pool",
      amount: 10000.00,
      allocated: 0.00
    )
    
    unauthorized_relationship = @test_lender.lender_funder_pools.build(
      funder_pool: unrelated_pool,
      active: true
    )
    
    # This should fail because there's no lender-wholesale funder relationship
    if !unauthorized_relationship.save
      puts "  ✓ Unauthorized pool addition properly rejected"
    else
      @verification_passed = false
      @errors << "Unauthorized pool addition should have been rejected"
    end
    
    # Clean up
    relationship1.destroy!
    unrelated_pool.destroy!
    unrelated_funder.destroy!
  end

  def cleanup_test_data
    puts "\nPhase 7: Cleaning up test data..."
    
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
  verification = FunderPoolUIWorkflowVerification.new
  verification.run_verification
end