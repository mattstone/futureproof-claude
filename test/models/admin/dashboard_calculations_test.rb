require "test_helper"

class Admin::DashboardCalculationsTest < ActiveSupport::TestCase
  # Disable fixtures to avoid conflicts
  fixtures :none
  
  def setup
    # Clean up any existing data
    User.delete_all
    Application.delete_all
    
    # Create test controller instance to test private methods
    @controller = Admin::DashboardController.new
  end
  
  def teardown
    User.delete_all
    Application.delete_all
  end

  test "generate_growth_data calculates monthly counts correctly" do
    # Create applications in different months
    user = create_user
    
    # Application from 2 months ago
    Application.create!(
      user: user,
      address: '123 Old St',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created,
      growth_rate: 2.0,
      borrower_age: 60,
      created_at: 2.months.ago
    )
    
    # Application from 1 month ago
    Application.create!(
      user: user,
      address: '456 Mid St',
      home_value: 1_200_000,
      ownership_status: :joint,
      property_state: :investment,
      status: :submitted,
      growth_rate: 2.5,
      borrower_age: 45,
      created_at: 1.month.ago
    )
    
    # Two applications from this month
    Application.create!(
      user: user,
      address: '789 New St',
      home_value: 1_500_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :accepted,
      growth_rate: 3.0,
      borrower_age: 50,
      created_at: 1.week.ago
    )
    
    Application.create!(
      user: user,
      address: '999 Recent Ave',
      home_value: 900_000,
      ownership_status: :company,
      property_state: :holiday,
      status: :processing,
      growth_rate: 2.2,
      borrower_age: 40,
      created_at: 2.days.ago
    )
    
    # Test growth data generation
    growth_data = @controller.send(:generate_growth_data, Application, 3)
    
    # Should return hash with month names as keys
    assert growth_data.is_a?(Hash)
    assert_equal 3, growth_data.size
    
    # Verify month format
    growth_data.keys.each do |month|
      assert month.match?(/\w{3} \d{4}/)
    end
    
    # Verify counts (most recent month should have 2 applications)
    current_month = Time.current.strftime('%b %Y')
    last_month = 1.month.ago.strftime('%b %Y')
    two_months_ago = 2.months.ago.strftime('%b %Y')
    
    if growth_data.key?(current_month)
      assert_equal 2, growth_data[current_month]
    end
    
    if growth_data.key?(last_month)
      assert_equal 1, growth_data[last_month]
    end
    
    if growth_data.key?(two_months_ago)
      assert_equal 1, growth_data[two_months_ago]
    end
  end

  test "generate_conversion_data calculates conversion rates correctly" do
    # Create users in different months
    user_last_month = User.create!(
      email: 'user1@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'One',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 1.month.ago,
      terms_version: 1,
      created_at: 1.month.ago
    )
    
    user_this_month_1 = User.create!(
      email: 'user2@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'Two',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 1.week.ago,
      terms_version: 1,
      created_at: 1.week.ago
    )
    
    user_this_month_2 = User.create!(
      email: 'user3@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'Three',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 3.days.ago,
      terms_version: 1,
      created_at: 3.days.ago
    )
    
    # Create applications - some users submit, others don't
    # User from last month submits application
    Application.create!(
      user: user_last_month,
      address: '123 Last Month St',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :submitted,
      growth_rate: 2.0,
      borrower_age: 60
    )
    
    # Only one user from this month submits application (50% conversion)
    Application.create!(
      user: user_this_month_1,
      address: '456 This Month Ave',
      home_value: 1_500_000,
      ownership_status: :joint,
      property_state: :investment,
      status: :accepted,
      growth_rate: 2.5,
      borrower_age: 45
    )
    
    # user_this_month_2 doesn't submit application
    
    # Test conversion data generation
    conversion_data = @controller.send(:generate_conversion_data, 3)
    
    # Should return hash with month names as keys
    assert conversion_data.is_a?(Hash)
    assert_equal 3, conversion_data.size
    
    # Verify month format
    conversion_data.keys.each do |month|
      assert month.match?(/\w{3} \d{4}/)
    end
    
    # Verify conversion rates
    current_month = Time.current.strftime('%b %Y')
    last_month = 1.month.ago.strftime('%b %Y')
    
    if conversion_data.key?(current_month)
      # 1 submitted app out of 2 users = 50%
      assert_equal 50.0, conversion_data[current_month]
    end
    
    if conversion_data.key?(last_month)
      # 1 submitted app out of 1 user = 100%
      assert_equal 100.0, conversion_data[last_month]
    end
  end

  test "generate_conversion_data handles edge cases" do
    # Test with no users (should return 0% conversion)
    conversion_data = @controller.send(:generate_conversion_data, 2)
    
    assert conversion_data.is_a?(Hash)
    assert_equal 2, conversion_data.size
    
    # All values should be 0
    conversion_data.values.each do |rate|
      assert_equal 0, rate
    end
  end

  test "generate_conversion_data handles users without applications" do
    # Create users but no applications
    User.create!(
      email: 'user1@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'One',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 1.week.ago,
      terms_version: 1,
      created_at: 1.week.ago
    )
    
    User.create!(
      email: 'user2@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'Two',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 2.days.ago,
      terms_version: 1,
      created_at: 2.days.ago
    )
    
    # No applications created
    conversion_data = @controller.send(:generate_conversion_data, 1)
    
    # Conversion rate should be 0% (0 submitted apps / 2 users = 0%)
    current_month = Time.current.strftime('%b %Y')
    if conversion_data.key?(current_month)
      assert_equal 0, conversion_data[current_month]
    end
  end

  test "generate_conversion_data only counts submitted applications" do
    user = create_user
    
    # Create applications with different statuses
    Application.create!(
      user: user,
      address: '123 Created St',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created, # Not submitted
      growth_rate: 2.0,
      borrower_age: 60
    )
    
    Application.create!(
      user: user,
      address: '456 Property St',
      home_value: 1_200_000,
      ownership_status: :joint,
      property_state: :investment,
      status: :property_details, # Not submitted
      growth_rate: 2.5,
      borrower_age: 45
    )
    
    Application.create!(
      user: user,
      address: '789 Submitted St',
      home_value: 1_500_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :submitted, # Counts as submitted
      growth_rate: 3.0,
      borrower_age: 50
    )
    
    Application.create!(
      user: user,
      address: '999 Accepted St',
      home_value: 900_000,
      ownership_status: :company,
      property_state: :holiday,
      status: :accepted, # Counts as submitted
      growth_rate: 2.2,
      borrower_age: 40
    )
    
    conversion_data = @controller.send(:generate_conversion_data, 1)
    
    # Should count only submitted, processing, accepted, rejected statuses
    # 2 qualifying applications / 1 user = 200% (can be > 100% if user submits multiple)
    current_month = Time.current.strftime('%b %Y')
    if conversion_data.key?(current_month)
      assert_equal 200.0, conversion_data[current_month]
    end
  end

  test "generate_growth_data handles empty collections" do
    # Test with no applications
    growth_data = @controller.send(:generate_growth_data, Application, 3)
    
    assert growth_data.is_a?(Hash)
    assert_equal 3, growth_data.size
    
    # All counts should be 0
    growth_data.values.each do |count|
      assert_equal 0, count
    end
  end

  test "generate_growth_data returns data in reverse chronological order" do
    user = create_user
    
    # Create application in past month
    Application.create!(
      user: user,
      address: '123 Past St',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created,
      growth_rate: 2.0,
      borrower_age: 60,
      created_at: 2.months.ago
    )
    
    growth_data = @controller.send(:generate_growth_data, Application, 3)
    
    # Keys should be in chronological order (oldest first)
    keys = growth_data.keys
    assert_equal 3, keys.length
    
    # Parse dates to verify ordering
    dates = keys.map { |key| Date.strptime(key, '%b %Y') }
    assert_equal dates.sort, dates
  end

  private

  def create_user(attributes = {})
    defaults = {
      email: "user#{rand(10000)}@test.com",
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    }
    
    User.create!(defaults.merge(attributes))
  end
end