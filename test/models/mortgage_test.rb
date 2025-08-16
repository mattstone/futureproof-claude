require "test_helper"

class MortgageTest < ActiveSupport::TestCase
  test "valid mortgage with valid LVR" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.5
    )
    assert mortgage.valid?
  end
  
  test "LVR must be present" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: nil
    )
    assert_not mortgage.valid?
    assert_includes mortgage.errors[:lvr], "can't be blank"
  end
  
  test "LVR must be at least 1" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 0.9
    )
    assert_not mortgage.valid?
    assert_includes mortgage.errors[:lvr], "must be greater than or equal to 1"
  end
  
  test "LVR must be at most 100" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 100.1
    )
    assert_not mortgage.valid?
    assert_includes mortgage.errors[:lvr], "must be less than or equal to 100"
  end
  
  test "LVR accepts exact boundaries" do
    # Test minimum boundary
    mortgage_min = Mortgage.new(
      name: "Test Mortgage Min",
      mortgage_type: :interest_only,
      lvr: 1.0
    )
    assert mortgage_min.valid?
    
    # Test maximum boundary
    mortgage_max = Mortgage.new(
      name: "Test Mortgage Max",
      mortgage_type: :interest_only,
      lvr: 100.0
    )
    assert mortgage_max.valid?
  end
  
  test "LVR must be in increments of 0.1" do
    # Valid increments
    valid_values = [1.0, 1.1, 1.2, 50.5, 80.7, 99.9, 100.0]
    valid_values.each do |lvr_value|
      mortgage = Mortgage.new(
        name: "Test Mortgage",
        mortgage_type: :interest_only,
        lvr: lvr_value
      )
      assert mortgage.valid?, "LVR #{lvr_value} should be valid"
    end
    
    # Invalid increments
    invalid_values = [1.01, 1.05, 50.55, 80.77, 99.99]
    invalid_values.each do |lvr_value|
      mortgage = Mortgage.new(
        name: "Test Mortgage",
        mortgage_type: :interest_only,
        lvr: lvr_value
      )
      assert_not mortgage.valid?, "LVR #{lvr_value} should be invalid"
      assert_includes mortgage.errors[:lvr], "must be in increments of 0.1 (e.g., 80.1, 80.2, etc.)"
    end
  end
  
  test "name must be present" do
    mortgage = Mortgage.new(
      name: "",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    assert_not mortgage.valid?
    assert_includes mortgage.errors[:name], "can't be blank"
  end
  
  test "mortgage_type must be present" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: nil,
      lvr: 80.0
    )
    assert_not mortgage.valid?
    assert_includes mortgage.errors[:mortgage_type], "can't be blank"
  end
  
  test "mortgage_type accepts valid enum values" do
    # Interest only
    mortgage_io = Mortgage.new(
      name: "Interest Only Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    assert mortgage_io.valid?
    assert_equal "interest_only", mortgage_io.mortgage_type
    
    # Principal and interest
    mortgage_pi = Mortgage.new(
      name: "P&I Mortgage",
      mortgage_type: :principal_and_interest,
      lvr: 75.5
    )
    assert mortgage_pi.valid?
    assert_equal "principal_and_interest", mortgage_pi.mortgage_type
  end
  
  test "mortgage_type_display returns proper labels" do
    mortgage_io = Mortgage.new(mortgage_type: :interest_only)
    assert_equal "Interest Only", mortgage_io.mortgage_type_display
    
    mortgage_pi = Mortgage.new(mortgage_type: :principal_and_interest)
    assert_equal "Principal and Interest", mortgage_pi.mortgage_type_display
  end
  
  test "formatted_lvr hides decimal point for whole numbers" do
    # Whole numbers should not show decimal
    mortgage_whole = Mortgage.new(lvr: 80.0)
    assert_equal "80%", mortgage_whole.formatted_lvr
    
    mortgage_whole2 = Mortgage.new(lvr: 75.0)
    assert_equal "75%", mortgage_whole2.formatted_lvr
    
    # Decimal numbers should show decimal
    mortgage_decimal = Mortgage.new(lvr: 80.5)
    assert_equal "80.5%", mortgage_decimal.formatted_lvr
    
    mortgage_decimal2 = Mortgage.new(lvr: 75.7)
    assert_equal "75.7%", mortgage_decimal2.formatted_lvr
    
    # Edge case: nil LVR
    mortgage_nil = Mortgage.new(lvr: nil)
    assert_equal "", mortgage_nil.formatted_lvr
  end
  
  test "change summary uses formatted LVR values" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    mortgage.save!
    
    # Simulate saved changes for LVR
    mortgage.define_singleton_method(:saved_change_to_lvr?) { true }
    mortgage.define_singleton_method(:saved_change_to_lvr) { [80.0, 75.5] }
    
    # Test the private method
    summary = mortgage.send(:build_change_summary)
    
    # Should show "80%" not "80.0%"
    assert_includes summary, "LVR changed from 80% to 75.5%"
    assert_not_includes summary, "80.0%"
  end

  # Lender association tests
  test "should belong to lender optionally" do
    lender = Lender.create!(
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "test@lender.com",
      country: "Australia"
    )
    
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0,
      lender: lender
    )
    
    assert mortgage.valid?
    assert_equal lender, mortgage.lender
  end

  test "should be valid without a lender" do
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0,
      lender: nil
    )
    
    assert mortgage.valid?
  end

  test "lender_name should return lender name or default message" do
    lender = Lender.create!(
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "test@lender.com",
      country: "Australia"
    )
    
    # With lender
    mortgage_with_lender = Mortgage.new(lender: lender)
    assert_equal "Test Lender", mortgage_with_lender.lender_name
    
    # Without lender
    mortgage_without_lender = Mortgage.new(lender: nil)
    assert_equal "No Lender Assigned", mortgage_without_lender.lender_name
  end

  test "should be able to assign and reassign lenders" do
    lender1 = Lender.create!(
      name: "Lender One",
      lender_type: :lender,
      contact_email: "one@lender.com",
      country: "Australia"
    )
    
    lender2 = Lender.create!(
      name: "Lender Two",
      lender_type: :futureproof,
      contact_email: "two@lender.com",
      country: "Australia"
    )
    
    mortgage = Mortgage.new(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0,
      lender: lender1
    )
    
    assert mortgage.valid?
    assert_equal lender1, mortgage.lender
    
    # Reassign lender
    mortgage.lender = lender2
    assert mortgage.valid?
    assert_equal lender2, mortgage.lender
    
    # Remove lender
    mortgage.lender = nil
    assert mortgage.valid?
    assert_nil mortgage.lender
  end
end
