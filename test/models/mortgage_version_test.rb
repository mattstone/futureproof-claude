require "test_helper"

class MortgageVersionTest < ActiveSupport::TestCase
  fixtures :users, :mortgages
  
  def setup
    @mortgage = mortgages(:basic_mortgage)
    @admin = users(:admin_user)
  end

  test "mortgage version records field changes" do
    version = MortgageVersion.new(
      mortgage: @mortgage,
      user: @admin,
      action: 'updated',
      previous_name: 'Old Mortgage',
      new_name: 'New Mortgage',
      previous_mortgage_type: 0, # interest_only
      new_mortgage_type: 1, # principal_and_interest
      previous_lvr: 80.0,
      new_lvr: 75.5
    )
    
    assert version.has_name_changes?
    assert version.has_mortgage_type_changes?
    assert version.has_lvr_changes?
    assert version.has_field_changes?
  end

  test "detailed_changes returns formatted LVR values" do
    version = MortgageVersion.new(
      mortgage: @mortgage,
      user: @admin,
      action: 'updated',
      previous_lvr: 80.0, # Should display as "80%"
      new_lvr: 75.5 # Should display as "75.5%"
    )
    
    changes = version.detailed_changes
    lvr_change = changes.find { |change| change[:field] == 'LVR' }
    
    assert_not_nil lvr_change
    assert_equal "80%", lvr_change[:from] # No decimal for whole number
    assert_equal "75.5%", lvr_change[:to] # Decimal shown when needed
  end

  test "detailed_changes handles various LVR values correctly" do
    # Test whole number to whole number
    version1 = MortgageVersion.new(
      previous_lvr: 80.0,
      new_lvr: 75.0
    )
    changes1 = version1.detailed_changes
    lvr_change1 = changes1.find { |change| change[:field] == 'LVR' }
    assert_equal "80%", lvr_change1[:from]
    assert_equal "75%", lvr_change1[:to]
    
    # Test decimal to decimal
    version2 = MortgageVersion.new(
      previous_lvr: 80.5,
      new_lvr: 75.7
    )
    changes2 = version2.detailed_changes
    lvr_change2 = changes2.find { |change| change[:field] == 'LVR' }
    assert_equal "80.5%", lvr_change2[:from]
    assert_equal "75.7%", lvr_change2[:to]
    
    # Test whole number to decimal
    version3 = MortgageVersion.new(
      previous_lvr: 80.0,
      new_lvr: 75.5
    )
    changes3 = version3.detailed_changes
    lvr_change3 = changes3.find { |change| change[:field] == 'LVR' }
    assert_equal "80%", lvr_change3[:from]
    assert_equal "75.5%", lvr_change3[:to]
  end

  test "mortgage_type_label returns correct labels" do
    version = MortgageVersion.new
    
    # Using send to access private method for testing
    assert_equal 'Interest Only', version.send(:mortgage_type_label, 0)
    assert_equal 'Principal and Interest', version.send(:mortgage_type_label, 1)
    assert_equal '99', version.send(:mortgage_type_label, 99)
  end

  test "format_lvr_for_display handles edge cases" do
    version = MortgageVersion.new
    
    # Using send to access private method for testing
    assert_equal "80%", version.send(:format_lvr_for_display, 80.0)
    assert_equal "75.5%", version.send(:format_lvr_for_display, 75.5)
    assert_equal "", version.send(:format_lvr_for_display, nil)
  end

  test "action_description returns proper descriptions" do
    version = MortgageVersion.new
    
    version.action = 'created'
    assert_equal 'created mortgage', version.action_description
    
    version.action = 'updated'
    assert_equal 'updated mortgage', version.action_description
    
    version.action = 'activated'
    assert_equal 'activated mortgage', version.action_description
    
    version.action = 'deactivated'
    assert_equal 'deactivated mortgage', version.action_description
  end

  test "has_lvr_changes detects changes correctly" do
    # No change
    version1 = MortgageVersion.new(previous_lvr: 80.0, new_lvr: 80.0)
    assert_not version1.has_lvr_changes?
    
    # With change
    version2 = MortgageVersion.new(previous_lvr: 80.0, new_lvr: 75.0)
    assert version2.has_lvr_changes?
    
    # Missing values
    version3 = MortgageVersion.new(previous_lvr: nil, new_lvr: 75.0)
    assert_not version3.has_lvr_changes?
    
    version4 = MortgageVersion.new(previous_lvr: 80.0, new_lvr: nil)
    assert_not version4.has_lvr_changes?
  end
end