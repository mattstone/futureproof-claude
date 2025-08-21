require "test_helper"

class ApplicationLenderNameFixTest < ActiveSupport::TestCase
  def setup
    @futureproof_lender = lenders(:futureproof)
    @user = users(:john)
  end

  test "application with lender ownership should use company_name not lender_name" do
    application = Application.create!(
      user: @user,
      address: "123 Test Street",
      home_value: 1500000,
      ownership_status: :lender,
      property_state: :primary_residence,
      company_name: "Test Lending Corp"
    )

    # The application should have company_name set
    assert_equal "Test Lending Corp", application.company_name
    
    # The application should NOT respond to lender_name (the bug we fixed)
    assert_not application.respond_to?(:lender_name)
    
    # But it should respond to company_name
    assert application.respond_to?(:company_name)
  end

  test "application with super fund ownership should use super_fund_name" do
    application = Application.create!(
      user: @user,
      address: "123 Test Street",
      home_value: 1500000,
      ownership_status: :super,
      property_state: :primary_residence,
      super_fund_name: "Smith Family SMSF"
    )

    assert_equal "Smith Family SMSF", application.super_fund_name
    assert application.respond_to?(:super_fund_name)
  end

  test "application with individual ownership should not require company_name or super_fund_name" do
    application = Application.create!(
      user: @user,
      address: "123 Test Street",
      home_value: 1500000,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 55
    )

    assert_nil application.company_name
    assert_nil application.super_fund_name
    assert application.valid?
  end

  test "application with joint ownership should not require company_name or super_fund_name" do
    application = Application.create!(
      user: @user,
      address: "123 Test Street", 
      home_value: 1500000,
      ownership_status: :joint,
      property_state: :primary_residence,
      borrower_names: JSON.generate([
        { "name" => "John Smith", "age" => 45 },
        { "name" => "Jane Smith", "age" => 42 }
      ])
    )

    assert_nil application.company_name
    assert_nil application.super_fund_name
    assert application.valid?
  end

  test "lender ownership validation requires company_name when not created status" do
    application = Application.new(
      user: @user,
      address: "123 Test Street",
      home_value: 1500000,
      ownership_status: :lender,
      property_state: :primary_residence,
      status: :property_details  # Not created status
    )

    assert_not application.valid?
    assert application.errors[:company_name].any?

    # Adding company_name should make it valid
    application.company_name = "Test Corp"
    assert application.valid?
  end

  test "super fund ownership validation requires super_fund_name when not created status" do
    application = Application.new(
      user: @user,
      address: "123 Test Street",
      home_value: 1500000,
      ownership_status: :super,
      property_state: :primary_residence,
      status: :property_details  # Not created status
    )

    assert_not application.valid?
    assert application.errors[:super_fund_name].any?

    # Adding super_fund_name should make it valid
    application.super_fund_name = "Test SMSF"
    assert application.valid?
  end
end