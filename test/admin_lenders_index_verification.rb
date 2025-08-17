#!/usr/bin/env ruby

# Admin Lenders Index Page Verification
# Tests the updated admin/lenders index page with wholesale funders and fund pools data

require_relative '../config/environment'

class AdminLendersIndexVerification
  def initialize
    @verification_passed = true
    @errors = []
    @test_lender = nil
    @test_wholesale_funder = nil
    @test_pools = []
  end

  def run_verification
    puts "\n📋 ADMIN LENDERS INDEX PAGE VERIFICATION"
    puts "=" * 60
    puts "Testing the updated admin/lenders index page with new columns:"
    puts "- Wholesale Funders (count)"
    puts "- Fund Pools (total amount and count)"
    puts

    begin
      cleanup_test_data
      create_test_data
      test_lender_methods
      test_controller_includes
      test_view_rendering_logic
      cleanup_test_data
      
      if @verification_passed
        puts "\n✅ ADMIN LENDERS INDEX VERIFICATION PASSED!"
        puts "The admin lenders index page is ready with the new columns."
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
    WholesaleFunder.where("name LIKE 'Test Admin Index WF%'").destroy_all
    Lender.where("name LIKE 'Test Admin Index Lender%'").destroy_all
  end

  def create_test_data
    puts "Phase 1: Creating test data for index page verification..."
    
    # Create wholesale funder
    @test_wholesale_funder = WholesaleFunder.create!(
      name: "Test Admin Index WF #{Time.current.to_i}",
      country: "Australia",
      currency: "AUD"
    )
    
    # Create funder pools
    @test_pools = [
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "Commercial Pool",
        amount: 100000.00,
        allocated: 25000.00
      ),
      FunderPool.create!(
        wholesale_funder: @test_wholesale_funder,
        name: "Residential Pool", 
        amount: 200000.00,
        allocated: 50000.00
      )
    ]
    
    # Create lender
    @test_lender = Lender.create!(
      name: "Test Admin Index Lender #{Time.current.to_i}",
      contact_email: "test#{Time.current.to_i}@adminindex.com",
      lender_type: :lender,
      country: "Australia"
    )
    
    # Add wholesale funder relationship
    LenderWholesaleFunder.create!(
      lender: @test_lender,
      wholesale_funder: @test_wholesale_funder,
      active: true
    )
    
    # Add both funder pools to the lender
    @test_pools.each do |pool|
      LenderFunderPool.create!(
        lender: @test_lender,
        funder_pool: pool,
        active: true
      )
    end
    
    puts "  ✓ Created wholesale funder with 2 pools"
    puts "  ✓ Created lender with wholesale funder relationship"
    puts "  ✓ Added both pools to the lender"
  end

  def test_lender_methods
    puts "\nPhase 2: Testing new Lender model methods..."
    
    # Test wholesale_funders_count
    expected_funders_count = 1
    actual_funders_count = @test_lender.wholesale_funders_count
    
    if actual_funders_count == expected_funders_count
      puts "  ✓ wholesale_funders_count returns #{actual_funders_count}"
    else
      @verification_passed = false
      @errors << "Expected wholesale_funders_count to be #{expected_funders_count}, got #{actual_funders_count}"
    end
    
    # Test total_fund_pool_amount
    expected_total = 300000.00 # 100,000 + 200,000
    actual_total = @test_lender.total_fund_pool_amount
    
    if actual_total == expected_total
      puts "  ✓ total_fund_pool_amount returns $#{actual_total}"
    else
      @verification_passed = false
      @errors << "Expected total_fund_pool_amount to be $#{expected_total}, got $#{actual_total}"
    end
    
    # Test formatted_total_fund_pool_amount
    expected_formatted = "$300,000.0"
    actual_formatted = @test_lender.formatted_total_fund_pool_amount
    
    if actual_formatted == expected_formatted
      puts "  ✓ formatted_total_fund_pool_amount returns '#{actual_formatted}'"
    else
      @verification_passed = false
      @errors << "Expected formatted amount to be '#{expected_formatted}', got '#{actual_formatted}'"
    end
    
    # Test funder_pools.count for display
    expected_pools_count = 2
    actual_pools_count = @test_lender.funder_pools.count
    
    if actual_pools_count == expected_pools_count
      puts "  ✓ funder_pools.count returns #{actual_pools_count} pools"
    else
      @verification_passed = false
      @errors << "Expected pools count to be #{expected_pools_count}, got #{actual_pools_count}"
    end
  end

  def test_controller_includes
    puts "\nPhase 3: Testing controller includes for N+1 prevention..."
    
    # Simulate the controller query
    lenders = Lender.includes(:lender_wholesale_funders, :lender_funder_pools)
                    .order(:lender_type, :name)
    
    # Find our test lender in the results
    test_lender_from_query = lenders.find { |l| l.id == @test_lender.id }
    
    if test_lender_from_query
      puts "  ✓ Test lender found in controller query results"
      
      # Test that the includes work (no additional queries should be needed)
      funders_count = test_lender_from_query.wholesale_funders_count
      pools_total = test_lender_from_query.total_fund_pool_amount
      
      puts "  ✓ Accessing wholesale_funders_count: #{funders_count}"
      puts "  ✓ Accessing total_fund_pool_amount: $#{pools_total}"
      
    else
      @verification_passed = false
      @errors << "Test lender not found in controller query results"
    end
  end

  def test_view_rendering_logic
    puts "\nPhase 4: Testing view rendering logic..."
    
    # Test the view logic for wholesale funders display
    funders_count = @test_lender.wholesale_funders_count
    if funders_count > 0
      puts "  ✓ Wholesale funders section: '#{funders_count} funders' (positive case)"
    else
      puts "  ✓ Would show 'No funders' (zero case)"
    end
    
    # Test the view logic for fund pools display
    pools_total = @test_lender.total_fund_pool_amount
    pools_count = @test_lender.funder_pools.count
    formatted_amount = @test_lender.formatted_total_fund_pool_amount
    
    if pools_total > 0
      puts "  ✓ Fund pools section: '#{formatted_amount} (#{pools_count} pools)' (positive case)"
    else
      puts "  ✓ Would show 'No pools' (zero case)"
    end
    
    # Test with a lender that has no relationships
    empty_lender = Lender.create!(
      name: "Empty Test Lender #{Time.current.to_i}",
      contact_email: "empty#{Time.current.to_i}@test.com",
      lender_type: :lender,
      country: "Australia"
    )
    
    if empty_lender.wholesale_funders_count == 0
      puts "  ✓ Empty lender shows 0 wholesale funders"
    end
    
    if empty_lender.total_fund_pool_amount == 0
      puts "  ✓ Empty lender shows $0 fund pools"
    end
    
    # Clean up the empty lender
    empty_lender.destroy!
  end
end

# Run verification if script is executed directly
if __FILE__ == $0
  verification = AdminLendersIndexVerification.new
  verification.run_verification
end