require "test_helper"

class ChangeTrackingTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      confirmed_at: Time.current,
      lender: lenders(:futureproof)
    )
  end

  test "wholesale funder tracks creation with change history" do
    wholesale_funder = WholesaleFunder.new(
      name: "Test Funder",
      country: "Australia", 
      currency: "AUD"
    )
    wholesale_funder.current_user = @user
    
    assert_difference 'WholesaleFunderVersion.count', 1 do
      wholesale_funder.save!
    end
    
    version = wholesale_funder.wholesale_funder_versions.last
    assert_equal 'created', version.action
    assert_equal @user, version.user
    assert_includes version.change_details, "Created new wholesale funder 'Test Funder'"
    assert_equal "Test Funder", version.new_name
    assert_equal "Australia", version.new_country
    assert_equal "AUD", version.new_currency
  end

  test "wholesale funder tracks updates with change history" do
    wholesale_funder = WholesaleFunder.create!(
      name: "Original Name",
      country: "Australia",
      currency: "AUD"
    )
    
    wholesale_funder.current_user = @user
    
    assert_difference 'WholesaleFunderVersion.count', 1 do
      wholesale_funder.update!(name: "Updated Name", country: "Canada")
    end
    
    version = wholesale_funder.wholesale_funder_versions.last
    assert_equal 'updated', version.action
    assert_equal @user, version.user
    assert_includes version.change_details, "Name changed from 'Original Name' to 'Updated Name'"
    assert_includes version.change_details, "Country changed from 'Australia' to 'Canada'"
    assert_equal "Original Name", version.previous_name
    assert_equal "Updated Name", version.new_name
    assert_equal "Australia", version.previous_country
    assert_equal "Canada", version.new_country
  end

  test "funder pool tracks creation with change history" do
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    funder_pool = FunderPool.new(
      wholesale_funder: wholesale_funder,
      name: "Test Pool",
      amount: 1000000,
      allocated: 200000,
      benchmark_rate: 4.0,
      margin_rate: 2.5
    )
    funder_pool.current_user = @user
    
    assert_difference 'FunderPoolVersion.count', 1 do
      funder_pool.save!
    end
    
    version = funder_pool.funder_pool_versions.last
    assert_equal 'created', version.action
    assert_equal @user, version.user
    assert_includes version.change_details, "Created new funder pool 'Test Pool'"
    assert_equal "Test Pool", version.new_name
    assert_equal 1000000, version.new_amount
    assert_equal 200000, version.new_allocated
  end

  test "funder pool tracks amount updates with currency formatting" do
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    funder_pool = FunderPool.create!(
      wholesale_funder: wholesale_funder,
      name: "Test Pool",
      amount: 1000000,
      allocated: 200000,
      benchmark_rate: 4.0,
      margin_rate: 2.5
    )
    
    funder_pool.current_user = @user
    
    assert_difference 'FunderPoolVersion.count', 1 do
      funder_pool.update!(amount: 1500000, allocated: 300000)
    end
    
    version = funder_pool.funder_pool_versions.last
    assert_equal 'updated', version.action
    assert_includes version.change_details, "Amount changed from $1,000,000 to $1,500,000"
    assert_includes version.change_details, "Allocated changed from $200,000 to $300,000"
  end

  test "lender tracks creation with change history" do
    lender = Lender.new(
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "test@lender.com",
      country: "Australia"
    )
    lender.current_user = @user
    
    assert_difference 'LenderVersion.count', 1 do
      lender.save!
    end
    
    version = lender.lender_versions.last
    assert_equal 'created', version.action
    assert_equal @user, version.user
    assert_includes version.change_details, "Created new lender 'Test Lender'"
    assert_equal "Test Lender", version.new_name
    assert_equal 1, version.new_lender_type # lender enum value
    assert_equal "test@lender.com", version.new_contact_email
  end

  test "lender tracks enum changes with proper formatting" do
    lender = Lender.create!(
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "test@lender.com",
      country: "Australia"
    )
    
    lender.current_user = @user
    
    assert_difference 'LenderVersion.count', 1 do
      lender.update!(lender_type: :futureproof)
    end
    
    version = lender.lender_versions.last
    assert_equal 'updated', version.action
    assert_includes version.change_details, "Lender type changed from 'Lender' to 'Futureproof'"
    assert_equal 1, version.previous_lender_type
    assert_equal 0, version.new_lender_type
  end

  test "log_view_by creates view version" do
    wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    assert_difference 'WholesaleFunderVersion.count', 1 do
      wholesale_funder.log_view_by(@user)
    end
    
    version = wholesale_funder.wholesale_funder_versions.last
    assert_equal 'viewed', version.action
    assert_equal @user, version.user
    assert_includes version.change_details, "#{@user.display_name} viewed wholesale funder 'Test Funder'"
  end

  test "change tracking works without current_user set" do
    wholesale_funder = WholesaleFunder.new(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    # Don't set current_user
    
    assert_no_difference 'WholesaleFunderVersion.count' do
      wholesale_funder.save!
    end
  end

  test "detailed_changes method returns proper field changes" do
    wholesale_funder = WholesaleFunder.create!(
      name: "Original Name",
      country: "Australia",
      currency: "AUD"
    )
    
    wholesale_funder.current_user = @user
    wholesale_funder.update!(name: "New Name", currency: "USD")
    
    version = wholesale_funder.wholesale_funder_versions.last
    changes = version.detailed_changes
    
    assert_equal 2, changes.length
    
    name_change = changes.find { |c| c[:field] == 'Name' }
    assert_equal "Original Name", name_change[:from]
    assert_equal "New Name", name_change[:to]
    
    currency_change = changes.find { |c| c[:field] == 'Currency' }
    assert_equal "AUD", currency_change[:from]
    assert_equal "USD", currency_change[:to]
  end
end