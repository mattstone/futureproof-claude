require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  def setup
    @futureproof = companies(:futureproof_financial)
    @broker = companies(:broker_company)
  end

  # === Validation Tests ===
  
  test "should be valid with valid attributes" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia",
      contact_email: "test@example.com"
    )
    assert company.valid?
  end

  test "should require name" do
    company = Company.new(
      company_type: :broker,
      country: "Australia",
      contact_email: "test@example.com"
    )
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "should require company_type" do
    company = Company.new(
      name: "Test Company",
      country: "Australia",
      contact_email: "test@example.com"
    )
    assert_not company.valid?
    assert_includes company.errors[:company_type], "can't be blank"
  end

  test "should require contact_email" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia"
    )
    assert_not company.valid?
    assert_includes company.errors[:contact_email], "can't be blank"
  end

  test "should require country" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      contact_email: "test@example.com",
      country: "" # Explicitly set to empty string to override default
    )
    assert_not company.valid?
    assert_includes company.errors[:country], "can't be blank"
  end

  test "should validate email format" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia",
      contact_email: "invalid-email"
    )
    assert_not company.valid?
    assert_includes company.errors[:contact_email], "is invalid"
  end

  test "should accept valid email formats" do
    valid_emails = [
      "test@example.com",
      "user.name@domain.co.uk",
      "test+tag@example.org"
    ]
    
    valid_emails.each do |email|
      company = Company.new(
        company_type: :broker,
        name: "Test Company",
        country: "Australia",
        contact_email: email
      )
      assert company.valid?, "#{email} should be valid"
    end
  end

  # === Enum Tests ===

  test "should have correct company_type enum values" do
    assert_equal 0, Company.company_types[:master]
    assert_equal 1, Company.company_types[:broker]
  end

  test "should have enum prefix methods" do
    assert @futureproof.company_type_master?
    assert_not @futureproof.company_type_broker?
    
    assert @broker.company_type_broker?
    assert_not @broker.company_type_master?
  end

  test "should have enum scopes" do
    master_companies = Company.company_type_master
    broker_companies = Company.company_type_broker
    
    assert_includes master_companies, @futureproof
    assert_not_includes master_companies, @broker
    
    assert_includes broker_companies, @broker
    assert_not_includes broker_companies, @futureproof
  end

  # === Master Company Singleton Tests ===

  test "should allow one master company" do
    # Futureproof already exists as master from fixtures
    assert @futureproof.company_type_master?
    assert @futureproof.valid?
  end

  test "should not allow second master company" do
    second_master = Company.new(
      company_type: :master,
      name: "Second Master",
      country: "Australia",
      contact_email: "second@master.com"
    )
    
    assert_not second_master.valid?
    assert_includes second_master.errors[:company_type], "Only one master company is allowed. Futureproof Financial is already the master company."
  end

  test "should allow editing existing master company" do
    @futureproof.name = "Updated Futureproof Financial"
    assert @futureproof.valid?
    assert @futureproof.save
  end

  test "should not allow changing broker to master when master exists" do
    @broker.company_type = :master
    assert_not @broker.valid?
    assert_includes @broker.errors[:company_type], "Only one master company is allowed. Futureproof Financial is already the master company."
  end

  test "should allow multiple broker companies" do
    new_broker = Company.new(
      company_type: :broker,
      name: "Another Broker",
      country: "Australia",
      contact_email: "another@broker.com"
    )
    
    assert new_broker.valid?
    assert new_broker.save
    
    # Should now have multiple brokers
    assert_operator Company.company_type_broker.count, :>=, 2
  end

  # === Default Values Tests ===

  test "should have default country of Australia" do
    company = Company.new
    assert_equal "Australia", company.country
  end

  test "should have default contact_telephone_country_code of +61" do
    company = Company.new
    assert_equal "+61", company.contact_telephone_country_code
  end

  # === Optional Fields Tests ===

  test "should allow nil address" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia",
      contact_email: "test@example.com",
      address: nil
    )
    assert company.valid?
  end

  test "should allow nil postcode" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia",
      contact_email: "test@example.com",
      postcode: nil
    )
    assert company.valid?
  end

  test "should allow nil contact_telephone" do
    company = Company.new(
      company_type: :broker,
      name: "Test Company",
      country: "Australia",
      contact_email: "test@example.com",
      contact_telephone: nil
    )
    assert company.valid?
  end

  # === Database Constraints Tests ===

  test "fixtures should be valid" do
    assert @futureproof.valid?, "Futureproof fixture should be valid: #{@futureproof.errors.full_messages}"
    assert @broker.valid?, "Broker fixture should be valid: #{@broker.errors.full_messages}"
  end

  test "should create company with all attributes" do
    company = Company.create!(
      company_type: :broker,
      name: "Full Test Company",
      address: "123 Test Street\nTest City",
      postcode: "1234",
      country: "New Zealand",
      contact_email: "full@test.com",
      contact_telephone: "0123456789",
      contact_telephone_country_code: "+64"
    )
    
    assert company.persisted?
    assert_equal "Full Test Company", company.name
    assert_equal "broker", company.company_type
    assert_equal "New Zealand", company.country
    assert_equal "+64", company.contact_telephone_country_code
  end
end
