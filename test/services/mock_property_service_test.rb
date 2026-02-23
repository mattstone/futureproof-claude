require "test_helper"

class MockPropertyServiceTest < ActiveSupport::TestCase
  test "search returns array of results" do
    results = MockPropertyService.search("123 Test St")
    assert_kind_of Array, results
    assert results.size > 0
    assert results.first.key?(:id)
    assert results.first.key?(:address)
  end

  test "search is deterministic" do
    assert_equal MockPropertyService.search("same query"), MockPropertyService.search("same query")
  end

  test "get_valuation returns expected keys" do
    val = MockPropertyService.get_valuation("123 Test St")
    %i[estimate low high confidence methodology comparable_sales market_trend annual_growth_rate risk_rating].each do |key|
      assert val.key?(key), "Missing key: #{key}"
    end
    assert val[:low] < val[:estimate]
    assert val[:high] > val[:estimate]
  end

  test "get_valuation is deterministic" do
    assert_equal MockPropertyService.get_valuation("addr")[:estimate], MockPropertyService.get_valuation("addr")[:estimate]
  end

  test "get_details returns expected keys" do
    details = MockPropertyService.get_details("123 Test St")
    %i[bedrooms bathrooms car_spaces land_area floor_area property_type year_built zoning council].each do |key|
      assert details.key?(key), "Missing key: #{key}"
    end
  end

  test "get_risk_assessment returns expected keys" do
    risk = MockPropertyService.get_risk_assessment("123 Test St")
    %i[overall_risk factors insurance_estimate_annual notes].each do |key|
      assert risk.key?(key), "Missing key: #{key}"
    end
    assert risk[:factors].key?(:flood)
  end
end
