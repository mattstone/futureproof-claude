require "test_helper"

class FunderPoolTest < ActiveSupport::TestCase
  setup do
    @funder_pool = funder_pools(:primary_pool)
  end

  # Association tests
  test "should belong to funder" do
    assert_respond_to @funder_pool, :funder
    assert_instance_of Funder, @funder_pool.funder
  end

  # Validation tests
  test "should be valid with valid attributes" do
    pool = FunderPool.new(
      funder: funders(:commbank_funder),
      name: "Test Pool",
      amount: 100000.00,
      allocated: 50000.00
    )
    assert pool.valid?
  end

  test "should require name" do
    @funder_pool.name = nil
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:name], "can't be blank"
  end

  test "should require amount" do
    @funder_pool.amount = nil
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:amount], "can't be blank"
  end

  test "should require allocated" do
    @funder_pool.allocated = nil
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:allocated], "can't be blank"
  end

  test "should validate name uniqueness within funder scope" do
    duplicate_pool = FunderPool.new(
      funder: @funder_pool.funder,
      name: @funder_pool.name,
      amount: 100000.00,
      allocated: 0.00
    )
    assert_not duplicate_pool.valid?
    assert_includes duplicate_pool.errors[:name], "already exists for this funder"
  end

  test "should allow same name for different funders" do
    different_funder_pool = FunderPool.new(
      funder: funders(:commbank_funder),
      name: @funder_pool.name,
      amount: 100000.00,
      allocated: 0.00
    )
    assert different_funder_pool.valid?
  end

  test "should validate name length" do
    @funder_pool.name = "a" * 256
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should validate amount is non-negative" do
    @funder_pool.amount = -1000.00
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:amount], "must be greater than or equal to 0"
  end

  test "should validate allocated is non-negative" do
    @funder_pool.allocated = -500.00
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:allocated], "must be greater than or equal to 0"
  end

  test "should validate allocated does not exceed amount" do
    @funder_pool.amount = 100000.00
    @funder_pool.allocated = 150000.00
    assert_not @funder_pool.valid?
    assert_includes @funder_pool.errors[:allocated], "cannot exceed the total amount"
  end

  test "should allow allocated to equal amount" do
    @funder_pool.amount = 100000.00
    @funder_pool.allocated = 100000.00
    assert @funder_pool.valid?
  end

  # Scope tests
  test "should have recent scope" do
    assert_respond_to FunderPool, :recent
    recent_pools = FunderPool.recent
    assert recent_pools.is_a?(ActiveRecord::Relation)
  end

  test "should have by_name scope" do
    assert_respond_to FunderPool, :by_name
    pools = FunderPool.by_name("Primary")
    assert pools.is_a?(ActiveRecord::Relation)
    pools.each do |pool|
      assert pool.name.downcase.include?("primary")
    end
  end

  # Method tests
  test "available_amount should return correct amount" do
    @funder_pool.amount = 1000.00
    @funder_pool.allocated = 300.00
    assert_equal 700.00, @funder_pool.available_amount
  end

  test "allocation_percentage should return correct percentage" do
    @funder_pool.amount = 1000.00
    @funder_pool.allocated = 250.00
    assert_equal 25.0, @funder_pool.allocation_percentage
  end

  test "allocation_percentage should return 0 when amount is 0" do
    @funder_pool.amount = 0.00
    @funder_pool.allocated = 0.00
    assert_equal 0, @funder_pool.allocation_percentage
  end

  test "formatted_amount should return formatted currency" do
    @funder_pool.amount = 1234567.89
    expected = "$1,234,567.89"
    assert_equal expected, @funder_pool.formatted_amount
  end

  test "formatted_allocated should return formatted currency" do
    @funder_pool.allocated = 987654.32
    expected = "$987,654.32"
    assert_equal expected, @funder_pool.formatted_allocated
  end

  test "formatted_available should return formatted currency" do
    @funder_pool.amount = 1000000.00
    @funder_pool.allocated = 250000.00
    expected = "$750,000.0"
    assert_equal expected, @funder_pool.formatted_available
  end

  test "display_name should include funder name" do
    expected = "#{@funder_pool.name} (#{@funder_pool.funder.name})"
    assert_equal expected, @funder_pool.display_name
  end

  # Integration tests
  test "should create pool with all attributes" do
    pool = FunderPool.create!(
      funder: funders(:hsbc_uk),
      name: "Integration Test Pool",
      amount: 500000.00,
      allocated: 100000.00
    )

    assert_equal "Integration Test Pool", pool.name
    assert_equal 500000.00, pool.amount
    assert_equal 100000.00, pool.allocated
    assert_equal 400000.00, pool.available_amount
    assert_equal 20.0, pool.allocation_percentage
  end

  test "should be destroyed when funder is destroyed" do
    funder = funders(:test_wholesale_fund)
    initial_pool_count = funder.funder_pools.count
    
    assert initial_pool_count > 0, "Funder should have pools for this test"
    
    assert_difference("FunderPool.count", -initial_pool_count) do
      funder.destroy
    end
  end

  test "should handle decimal precision correctly" do
    pool = FunderPool.create!(
      funder: funders(:jp_morgan),
      name: "Precision Test",
      amount: 1234.56,
      allocated: 123.45
    )
    
    assert_equal 1234.56, pool.amount
    assert_equal 123.45, pool.allocated
    assert_equal 1111.11, pool.available_amount
  end

  # Association tests
  test "should have mortgage associations through join table" do
    mortgage = mortgages(:basic_mortgage)
    MortgageFunderPool.create!(mortgage: mortgage, funder_pool: @funder_pool, active: true)
    
    assert_includes @funder_pool.mortgages, mortgage
  end
end
