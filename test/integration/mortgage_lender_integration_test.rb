require "test_helper"

class MortgageLenderIntegrationTest < ActionDispatch::IntegrationTest
  test "complete mortgage and lender workflow" do
    # Create test lenders
    futureproof_lender = Lender.create!(
      name: "Futureproof Test",
      lender_type: :futureproof,
      contact_email: "test@futureproof.com",
      country: "Australia"
    )
    
    broker_lender = Lender.create!(
      name: "Broker Test",
      lender_type: :lender,
      contact_email: "test@broker.com",
      country: "Australia"
    )
    
    # Test 1: Create mortgage without lender
    mortgage1 = Mortgage.create!(
      name: "Test Mortgage 1",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    assert mortgage1.valid?
    assert_nil mortgage1.lender
    assert_equal "No Lender Assigned", mortgage1.lender_name
    
    # Test 2: Create mortgage with lender
    mortgage2 = Mortgage.create!(
      name: "Test Mortgage 2",
      mortgage_type: :principal_and_interest,
      lvr: 75.5,
      lender: futureproof_lender
    )
    
    assert mortgage2.valid?
    assert_equal futureproof_lender, mortgage2.lender
    assert_equal "Futureproof Test", mortgage2.lender_name
    
    # Test 3: Update mortgage to add lender
    mortgage1.lender = broker_lender
    mortgage1.save!
    
    mortgage1.reload
    assert_equal broker_lender, mortgage1.lender
    assert_equal "Broker Test", mortgage1.lender_name
    
    # Test 4: Update mortgage to remove lender
    mortgage1.lender = nil
    mortgage1.save!
    
    mortgage1.reload
    assert_nil mortgage1.lender
    assert_equal "No Lender Assigned", mortgage1.lender_name
    
    # Test 5: Verify lender has mortgages relationship
    assert_includes futureproof_lender.mortgages, mortgage2
    
    # Test 6: Delete lender with mortgages should fail (restrict_with_exception)
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      futureproof_lender.destroy
    end
    
    # Test 7: Remove mortgage from lender, then delete should work
    mortgage2.lender = nil
    mortgage2.save!
    
    assert_nothing_raised do
      futureproof_lender.destroy
    end
    
    # Cleanup
    mortgage1.destroy
    mortgage2.destroy
    broker_lender.destroy
  end
end