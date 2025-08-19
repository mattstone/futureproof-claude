require 'test_helper'

class MortgageContractTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  
  def self.use_instantiated_fixtures
    false
  end
  
  def self.fixture_path
    nil
  end
  setup do
    User.delete_all
    Lender.delete_all
    Mortgage.delete_all
    MortgageContract.delete_all
    
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User", 
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      address: "123 Admin Street"
    )
    
    @lender = Lender.create!(
      name: "Test Lender",
      contact_email: "test@lender.com",
      lender_type: :futureproof,
      address: "456 Lender Ave"
    )
    
    @mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    @mortgage.mortgage_lenders.create!(lender: @lender, active: true)
  end
  
  test "can create a new mortgage contract" do
    contract = @mortgage.mortgage_contracts.build(
      title: "Test Contract",
      content: "## Test\n\nThis is a test contract.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    contract.current_user = @admin
    
    assert contract.save
    assert_equal "Test Contract", contract.title
    assert contract.draft?
    assert_not contract.is_active?
  end
  
  test "can publish a draft contract" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Draft Contract",
      content: "## Test\n\nDraft content.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    contract.current_user = @admin
    
    contract.publish!
    
    assert contract.published?
    assert_not contract.draft?
  end
  
  test "can activate a published contract" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Published Contract",
      content: "## Test\n\nPublished content.",
      is_draft: false,
      is_active: false,
      created_by: @admin
    )
    contract.current_user = @admin
    
    contract.activate!
    
    assert contract.is_active?
    assert contract.published?
  end
  
  test "validates required fields" do
    contract = MortgageContract.new
    
    assert_not contract.valid?
    assert_includes contract.errors[:title], "can't be blank"
    assert_includes contract.errors[:content], "can't be blank"
  end
  
  test "renders content with placeholders" do
    @admin.update!(lender: @lender)
    customer = User.create!(
      first_name: "John",
      last_name: "Smith",
      email: "john@example.com", 
      password: "password123",
      password_confirmation: "password123",
      admin: false,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      lender: @lender,
      address: "789 Customer Rd"
    )
    
    contract = @mortgage.mortgage_contracts.create!(
      title: "Placeholder Test",
      content: "## Agreement\n\n**Customer:** {{primary_user_full_name}}\n**Address:** {{primary_user_address}}\n**Lender:** {{lender_name}}",
      is_draft: true,
      is_active: false,
      created_by: @admin,
      primary_user: customer
    )
    
    rendered = contract.rendered_content
    
    assert_includes rendered, "John Smith"
    assert_includes rendered, "789 Customer Rd"
    assert_includes rendered, "Test Lender"
  end
end