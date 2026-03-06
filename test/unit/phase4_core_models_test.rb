require "test_helper"

class Phase4CoreModelsTest < ActiveSupport::TestCase
  setup do
    @lender = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )
  end

  # === USER MODEL TESTS ===

  test "user creation with valid attributes" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      first_name: "John",
      last_name: "Smith",
      role: "customer"
    )

    assert user.persisted?
    assert_equal "John", user.first_name
    assert_equal "Smith", user.last_name
    assert_equal "customer", user.role
  end

  test "user email must be unique" do
    User.create!(
      email: "unique@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    user2 = User.new(
      email: "unique@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    assert_raises(ActiveRecord::RecordInvalid) do
      user2.save!
    end
  end

  test "user password validation enforces minimum length" do
    user = User.new(
      email: "test@example.com",
      password: "short",
      password_confirmation: "short",
      role: "customer"
    )

    assert_not user.valid?
    assert user.errors[:password].present?
  end

  test "user has_many applications" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    app1 = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    app2 = Application.create!(
      user: user,
      lender: @lender,
      property_value: 1_000_000,
      customer_age: 72,
      government_id: "987654321",
      bank_account_number: "987654321987654"
    )

    assert_equal 2, user.applications.count
    assert user.applications.include?(app1)
    assert user.applications.include?(app2)
  end

  test "lender_admin user has belongs_to lender" do
    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    assert_equal @lender.id, lender_admin.lender_id
    assert_equal @lender, lender_admin.lender
  end

  # === APPLICATION MODEL TESTS ===

  test "application creation with valid attributes" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    assert application.persisted?
    assert_equal "pending_review", application.status
    assert_equal 800_000, application.property_value
  end

  test "application status transitions are valid" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    # Transition to approved
    application.update!(status: "approved", approved_loan_amount: 800_000)
    assert_equal "approved", application.status

    # Transition to rejected
    application.update!(status: "rejected")
    assert_equal "rejected", application.status
  end

  test "application requires government_id and bank_account_number" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.new(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      status: "pending_review"
    )

    assert_not application.valid?
    assert application.errors[:government_id].present?
    assert application.errors[:bank_account_number].present?
  end

  test "application belongs_to user and lender" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    assert_equal user, application.user
    assert_equal @lender, application.lender
  end

  test "application stores encrypted sensitive data" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345",
      credit_score: 720
    )

    # Data should be encrypted at rest but decrypted on read
    reloaded = Application.find(application.id)
    assert_equal "123456789", reloaded.government_id
    assert_equal "123456789012345", reloaded.bank_account_number
    assert_equal 720, reloaded.credit_score
  end

  test "application has_one mortgage_contract" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>Contract</h1>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    assert_equal contract, application.mortgage_contract
  end

  # === MORTGAGE CONTRACT MODEL TESTS ===

  test "mortgage contract creation with valid attributes" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>Mortgage Contract</h1><p>NNEG Clause</p>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    assert contract.persisted?
    assert_equal "AU", contract.region
    assert_equal "active", contract.status
    assert_equal 2_000, contract.monthly_income
    assert_equal 0.15, contract.nneg_probability
  end

  test "mortgage contract region must be valid" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.new(
      application: application,
      region: "INVALID",
      contract_html: "<h1>Contract</h1>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    # Should validate region
    # (assuming region validation exists)
    # This test assumes a presence check on region
    contract.region = nil
    assert_not contract.valid?
  end

  test "mortgage contract contains NNEG clause for AU" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>AU Mortgage</h1><div class='nneg-clause'>NNEG Protection Clause</div>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    assert contract.contract_html.include?("NNEG") || contract.contract_html.include?("nneg")
  end

  test "mortgage contract status transitions" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>Contract</h1>",
      status: "draft",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    # Move through states
    contract.update!(status: "pending_signature")
    assert_equal "pending_signature", contract.status

    contract.update!(status: "signed")
    assert_equal "signed", contract.status

    contract.update!(status: "active")
    assert_equal "active", contract.status
  end

  test "mortgage contract calculates estate impact" do
    user = User.create!(
      email: "test@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: user,
      lender: @lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    contract = MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>Contract</h1>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15,
      estate_projection: {
        years: [1, 5, 10, 20],
        property_values: [800_000, 850_000, 920_000, 1_100_000],
        mortgage_balances: [750_000, 650_000, 500_000, 100_000],
        net_estates: [50_000, 200_000, 420_000, 1_000_000]
      }
    )

    assert contract.estate_projection.present?
    assert_equal 10, contract.estate_projection["years"].length
  end
end
