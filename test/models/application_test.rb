require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  # Disable fixtures for this test to avoid conflicts
  fixtures :none
  
  def teardown
    Application.delete_all
    User.delete_all
  end
  def setup
    # Use a unique email for each test run
    @user = User.create!(
      email: "test#{rand(100000)}@example.com",
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
    
    @application = Application.new(
      user: @user,
      address: '123 Test Street, Sydney NSW 2000',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created,
      growth_rate: 2.0,
      borrower_age: 60
    )
  end

  test "should create application with valid attributes" do
    assert @application.valid?
    assert @application.save
  end

  test "display_address should return address when present" do
    @application.address = '123 Test Street, Sydney NSW 2000'
    assert_equal '123 Test Street, Sydney NSW 2000', @application.display_address
  end

  test "display_address should return fallback when address is nil" do
    @application.address = nil
    assert_equal 'Address not set', @application.display_address
  end

  test "display_address should return fallback when address is empty" do
    @application.address = ''
    assert_equal 'Address not set', @application.display_address
  end

  test "display_address should return fallback when address is blank" do
    @application.address = '   '
    assert_equal 'Address not set', @application.display_address
  end

  test "formatted_home_value should return currency format" do
    @application.home_value = 1_500_000
    assert_equal '$1,500,000', @application.formatted_home_value
  end

  test "formatted_existing_mortgage_amount should return N/A when no mortgage" do
    @application.has_existing_mortgage = false
    assert_equal 'N/A', @application.formatted_existing_mortgage_amount
  end

  test "formatted_existing_mortgage_amount should return currency when has mortgage" do
    @application.has_existing_mortgage = true
    @application.existing_mortgage_amount = 500_000
    assert_equal '$500,000', @application.formatted_existing_mortgage_amount
  end

  test "status_display should return humanized status" do
    @application.status = :created
    assert_equal 'Created', @application.status_display
    
    @application.status = :submitted
    assert_equal 'Submitted', @application.status_display
  end

  test "ownership_status_display should return humanized ownership status" do
    @application.ownership_status = :individual
    assert_equal 'Individual', @application.ownership_status_display
    
    @application.ownership_status = :joint
    assert_equal 'Joint', @application.ownership_status_display
  end

  test "property_state_display should return humanized property state" do
    @application.property_state = :primary_residence
    assert_equal 'Primary residence', @application.property_state_display
    
    @application.property_state = :investment
    assert_equal 'Investment', @application.property_state_display
  end

  test "status_badge_class should return correct CSS class" do
    @application.status = :created
    assert_equal 'badge-secondary', @application.status_badge_class
    
    @application.status = :submitted
    assert_equal 'badge-info', @application.status_badge_class
    
    @application.status = :accepted
    assert_equal 'badge-success', @application.status_badge_class
    
    @application.status = :rejected
    assert_equal 'badge-danger', @application.status_badge_class
  end

  test "can_be_edited should return true for editable statuses" do
    @application.status = :created
    assert @application.can_be_edited?
    
    @application.status = :property_details
    assert @application.can_be_edited?
    
    @application.status = :income_and_loan_options
    assert @application.can_be_edited?
  end

  test "can_be_edited should return false for non-editable statuses" do
    @application.status = :submitted
    assert_not @application.can_be_edited?
    
    @application.status = :accepted
    assert_not @application.can_be_edited?
    
    @application.status = :rejected
    assert_not @application.can_be_edited?
  end

  test "next_step should return correct next status" do
    @application.status = :created
    assert_equal 'property_details', @application.next_step
    
    @application.status = :property_details
    assert_equal 'income_and_loan_options', @application.next_step
    
    @application.status = :income_and_loan_options
    assert_equal 'submitted', @application.next_step
    
    @application.status = :submitted
    assert_nil @application.next_step
  end

  test "progress_percentage should return correct percentage" do
    @application.status = :created
    assert_equal 0, @application.progress_percentage
    
    @application.status = :property_details
    assert_equal 50, @application.progress_percentage
    
    @application.status = :income_and_loan_options
    assert_equal 75, @application.progress_percentage
    
    @application.status = :submitted
    assert_equal 100, @application.progress_percentage
  end

  test "should assign demo address on create when address is blank" do
    @application.address = nil
    @application.save!
    
    assert_not_nil @application.address
    assert @application.address.length > 0
    assert @application.address.include?('NSW')
  end

  test "should not overwrite existing address on create" do
    original_address = '456 Custom Street, Melbourne VIC 3000'
    @application.address = original_address
    @application.save!
    
    assert_equal original_address, @application.address
  end

  test "formatted_growth_rate should return percentage format" do
    @application.growth_rate = 2.5
    assert_equal '2.5%', @application.formatted_growth_rate
    
    @application.growth_rate = nil
    assert_equal '2.0%', @application.formatted_growth_rate  # Default value
  end
end
