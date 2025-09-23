require 'test_helper'

class UserRegistrationModelsTest < ActiveSupport::TestCase
  def setup
    # Clean up any existing test data
    User.where(email: [
      'unit.customer@test.com',
      'unit.admin@test.com',
      'model.test@test.com'
    ]).destroy_all
  end

  test "user model validations work correctly" do
    # Valid customer user
    user = User.new(
      first_name: "Valid",
      last_name: "Customer",
      email: "unit.customer@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      admin: false
    )
    assert user.valid?, "Valid customer user should pass validation: #{user.errors.full_messages}"

    # Invalid user - missing required fields
    invalid_user = User.new
    assert_not invalid_user.valid?, "User with no data should fail validation"
    assert invalid_user.errors[:first_name].any?, "Should require first name"
    assert invalid_user.errors[:last_name].any?, "Should require last name"
    assert invalid_user.errors[:email].any?, "Should require email"
    assert invalid_user.errors[:terms_accepted].any?, "Should require terms acceptance"
    # Note: country_of_residence might not be required in all cases
  end

  test "lender requirement is conditional based on admin status" do
    # Customer users should NOT require lender
    customer = User.new(
      first_name: "Customer",
      last_name: "User",
      email: "unit.customer@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      admin: false,
      lender: nil
    )
    assert customer.valid?, "Customer should not require lender: #{customer.errors.full_messages}"

    # Admin users SHOULD require lender (if we had a lender to assign)
    admin = User.new(
      first_name: "Admin",
      last_name: "User",
      email: "unit.admin@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      admin: true,
      lender: nil
    )
    assert_not admin.valid?, "Admin should require lender"
    assert admin.errors[:lender].any?, "Should have lender validation error for admin"
  end

  test "user creation triggers application creation callback for customers" do
    # Test customer gets automatic application
    assert_difference ['User.count', 'Application.count'], 1 do
      User.create!(
        first_name: "Callback",
        last_name: "Customer",
        email: "model.test@test.com",
        password: "password123",
        country_of_residence: "Australia",
        terms_accepted: true,
        admin: false
      )
    end

    user = User.find_by(email: "model.test@test.com")
    assert_equal 1, user.applications.count, "Customer should get automatic application"

    application = user.applications.first
    assert application.status_created?, "Auto-created application should have created status"
    assert_equal 1000000, application.home_value, "Should have default home value"
    assert application.ownership_status_individual?, "Should default to individual ownership"
    assert application.property_state_primary_residence?, "Should default to primary residence"
    assert_not application.has_existing_mortgage?, "Should default to no existing mortgage"
    assert_equal 0, application.existing_mortgage_amount
    assert_equal 2.0, application.growth_rate
    assert_equal 60, application.borrower_age
    assert_nil application.address, "Address should be nil for created status"
  end

  test "application address validation is conditional on status" do
    user = User.create!(
      first_name: "Address",
      last_name: "Test",
      email: "address.validation@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true
    )

    application = user.applications.first

    # Created status should allow nil address
    assert application.status_created?
    assert_nil application.address
    assert application.valid?, "Created status should allow nil address"

    # Test each status transition requiring address
    non_created_statuses = [:user_details, :property_details, :income_and_loan_options, :submitted, :processing, :accepted]

    non_created_statuses.each do |status|
      application.status = status
      assert_not application.valid?, "Status #{status} should require address"
      assert application.errors[:address].any?, "Should have address error for status #{status}"

      # Should be valid with address
      application.address = "123 Test Street, Sydney NSW 2000"
      assert application.valid?, "Status #{status} should be valid with address"
      application.address = nil # Reset for next iteration
    end
  end

  test "application model has correct default values" do
    user = User.create!(
      first_name: "Defaults",
      last_name: "Test",
      email: "defaults.test@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true
    )

    application = user.applications.first

    # Test all expected defaults
    assert_equal "created", application.status
    assert_equal "individual", application.ownership_status
    assert_equal "primary_residence", application.property_state
    assert_equal 1000000, application.home_value
    assert_not application.has_existing_mortgage?
    assert_equal 0, application.existing_mortgage_amount
    assert_equal 2.0, application.growth_rate
    assert_equal 60, application.borrower_age
    assert_nil application.address
    assert_nil application.mortgage_id
    assert_nil application.rejected_reason
    assert_nil application.borrower_names
    assert_nil application.company_name
    assert_nil application.super_fund_name
  end

  test "application validates required fields for non-created status" do
    user = User.create!(
      first_name: "Validation",
      last_name: "Test",
      email: "validation.test@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true
    )

    application = user.applications.first
    application.status = :user_details
    application.address = "123 Valid Street, Sydney NSW 2000"

    # Should be valid with basic required fields
    assert application.valid?, "Should be valid with address for user_details status"

    # Test home value validation
    application.home_value = 0
    assert_not application.valid?, "Should require positive home value"
    assert application.errors[:home_value].any?

    application.home_value = 1000000
    assert application.valid?, "Should be valid with positive home value"

    # Test home value upper limit
    application.home_value = 51_000_000
    assert_not application.valid?, "Should enforce home value upper limit"
    assert application.errors[:home_value].any?
  end

  test "user email uniqueness is scoped to lender" do
    # Create first user with no lender
    user1 = User.create!(
      first_name: "First",
      last_name: "User",
      email: "duplicate@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      lender: nil
    )

    # Should be able to create another user with same email and no lender
    # because the uniqueness is scoped to lender_id
    user2 = User.new(
      first_name: "Second",
      last_name: "User",
      email: "duplicate@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      lender: nil
    )

    # This should fail because both have nil lender_id
    assert_not user2.valid?, "Should not allow duplicate email with same lender scope"
    assert user2.errors[:email].any?, "Should have email uniqueness error"
  end

  test "application belongs to user relationship works correctly" do
    user = User.create!(
      first_name: "Relationship",
      last_name: "Test",
      email: "relationship.test@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true
    )

    application = user.applications.first

    # Test the relationship
    assert_equal user, application.user
    assert_equal user.id, application.user_id
    assert_includes user.applications, application

    # Test dependent destroy
    user_id = user.id
    application_id = application.id

    user.destroy

    assert_nil User.find_by(id: user_id), "User should be destroyed"
    assert_nil Application.find_by(id: application_id), "Application should be destroyed with user"
  end

  test "user model has correct admin detection" do
    customer = User.create!(
      first_name: "Customer",
      last_name: "User",
      email: "customer.admin.test@test.com",
      password: "password123",
      country_of_residence: "Australia",
      terms_accepted: true,
      admin: false
    )

    assert_not customer.admin?, "Customer should not be admin"

    # We can't easily test admin creation due to lender requirement,
    # but we can test the admin? method
    customer.admin = true
    assert customer.admin?, "User with admin=true should be admin"
  end
end