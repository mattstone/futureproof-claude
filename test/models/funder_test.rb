require "test_helper"

class FunderTest < ActiveSupport::TestCase
  setup do
    @funder = funders(:test_wholesale_fund)
  end

  # Validation tests
  test "should be valid with valid attributes" do
    funder = Funder.new(
      name: "Test Bank",
      country: "Australia",
      currency: "AUD"
    )
    assert funder.valid?
  end

  test "should require name" do
    @funder.name = nil
    assert_not @funder.valid?
    assert_includes @funder.errors[:name], "can't be blank"
  end

  test "should require country" do
    @funder.country = nil
    assert_not @funder.valid?
    assert_includes @funder.errors[:country], "can't be blank"
  end

  test "should require currency" do
    @funder.currency = nil
    assert_not @funder.valid?
    assert_includes @funder.errors[:currency], "can't be blank"
  end

  test "should validate name uniqueness" do
    duplicate_funder = Funder.new(
      name: @funder.name,
      country: "Different Country",
      currency: "USD"
    )
    assert_not duplicate_funder.valid?
    assert_includes duplicate_funder.errors[:name], "has already been taken"
  end

  test "should validate name length" do
    @funder.name = "a" * 256
    assert_not @funder.valid?
    assert_includes @funder.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should validate country length" do
    @funder.country = "a" * 101
    assert_not @funder.valid?
    assert_includes @funder.errors[:country], "is too long (maximum is 100 characters)"
  end

  test "should validate currency inclusion" do
    @funder.currency = "INVALID"
    assert_not @funder.valid?
    assert_includes @funder.errors[:currency], "is not included in the list"
  end

  test "should allow valid currencies" do
    %w[AUD USD GBP].each do |currency|
      @funder.currency = currency
      assert @funder.valid?, "#{currency} should be valid"
    end
  end

  # Currency methods tests
  test "should have currency enum-like class method" do
    assert_respond_to Funder, :currencies
    assert_equal({ "aud" => "AUD", "usd" => "USD", "gbp" => "GBP" }, Funder.currencies)
  end

  test "should default currency to AUD" do
    funder = Funder.new(name: "Test", country: "Test")
    assert_equal "AUD", funder.currency
  end

  test "should have currency prefix methods" do
    @funder.currency = "USD"
    assert @funder.currency_usd?
    assert_not @funder.currency_aud?
    assert_not @funder.currency_gbp?
  end

  # Scope tests
  test "should have recent scope" do
    assert_respond_to Funder, :recent
    recent_funders = Funder.recent
    assert recent_funders.is_a?(ActiveRecord::Relation)
  end

  test "should have by_country scope" do
    assert_respond_to Funder, :by_country
    australia_funders = Funder.by_country("Australia")
    assert australia_funders.is_a?(ActiveRecord::Relation)
    australia_funders.each do |funder|
      assert_equal "Australia", funder.country
    end
  end

  test "should have by_currency scope" do
    assert_respond_to Funder, :by_currency
    aud_funders = Funder.by_currency("AUD")
    assert aud_funders.is_a?(ActiveRecord::Relation)
    aud_funders.each do |funder|
      assert_equal "AUD", funder.currency
    end
  end

  # Helper method tests
  test "display_name should include country" do
    expected = "#{@funder.name} (#{@funder.country})"
    assert_equal expected, @funder.display_name
  end

  test "currency_symbol should return correct symbol" do
    @funder.currency = "AUD"
    assert_equal "A$", @funder.currency_symbol

    @funder.currency = "USD"
    assert_equal "$", @funder.currency_symbol

    @funder.currency = "GBP"
    assert_equal "£", @funder.currency_symbol
  end

  test "currency_symbol should default to currency code for unknown" do
    # Temporarily set an invalid currency to test fallback
    @funder.update_column(:currency, "XYZ")
    assert_equal "XYZ", @funder.currency_symbol
  end

  # Database index tests
  test "should have database indexes" do
    connection = ActiveRecord::Base.connection
    indexes = connection.indexes("funders")
    
    index_columns = indexes.map(&:columns).flatten
    assert_includes index_columns, "name"
    assert_includes index_columns, "country"  
    assert_includes index_columns, "currency"
  end

  # Integration tests
  test "should create funder with all attributes" do
    funder = Funder.create!(
      name: "Integration Test Bank",
      country: "Canada",
      currency: "USD"
    )

    assert_equal "Integration Test Bank", funder.name
    assert_equal "Canada", funder.country
    assert_equal "USD", funder.currency
    assert_equal "Integration Test Bank (Canada)", funder.display_name
    assert_equal "$", funder.currency_symbol
  end

  test "should handle currency assignment" do
    @funder.currency = "USD"
    assert_equal "USD", @funder.currency

    @funder.currency = "GBP"
    assert_equal "GBP", @funder.currency
  end

  # FunderPool summary tests
  test "pools_count should return correct count" do
    assert_equal 2, @funder.pools_count
  end

  test "total_capital should sum all pool amounts" do
    expected_total = @funder.funder_pools.sum(:amount)
    assert_equal expected_total, @funder.total_capital
  end

  test "total_allocated should sum all pool allocated amounts" do
    expected_allocated = @funder.funder_pools.sum(:allocated)
    assert_equal expected_allocated, @funder.total_allocated
  end

  test "total_available should calculate correctly" do
    expected_available = @funder.total_capital - @funder.total_allocated
    assert_equal expected_available, @funder.total_available
  end

  test "formatted methods should return properly formatted currency" do
    assert_match /^\$[\d,]+\.?\d*$/, @funder.formatted_total_capital
    assert_match /^\$[\d,]+\.?\d*$/, @funder.formatted_total_allocated
    assert_match /^\$[\d,]+\.?\d*$/, @funder.formatted_total_available
  end

  test "capital_allocation_percentage should calculate correctly" do
    if @funder.total_capital > 0
      expected_percentage = (@funder.total_allocated / @funder.total_capital * 100).round(2)
      assert_equal expected_percentage, @funder.capital_allocation_percentage
    else
      assert_equal 0, @funder.capital_allocation_percentage
    end
  end

  test "should handle funder with no pools" do
    funder_no_pools = funders(:hsbc_uk)
    assert_equal 0, funder_no_pools.pools_count
    assert_equal 0, funder_no_pools.total_capital
    assert_equal 0, funder_no_pools.total_allocated
    assert_equal 0, funder_no_pools.capital_allocation_percentage
  end
end
