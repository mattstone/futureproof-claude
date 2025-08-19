require 'test_helper'

class MortgageContractPlaceholdersUnitTest < ActiveSupport::TestCase
  def setup
    # Clear all data
    User.delete_all
    Lender.delete_all
    Mortgage.delete_all
    MortgageContract.delete_all
    
    # Create test data
    @admin = User.create!(
      first_name: "Admin",
      last_name: "User",
      email: "admin@futureproof.app",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      address: "456 Collins Street, Melbourne VIC 3000"
    )
    
    @lender = Lender.create!(
      name: "Futureproof Financial Group",
      contact_email: "contact@futureproof.app",
      lender_type: :futureproof,
      address: "456 Collins Street, Melbourne VIC 3000"
    )
    
    @admin.update!(lender: @lender)
    
    @customer = User.create!(
      first_name: "John",
      last_name: "Smith",
      email: "john@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: false,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      lender: @lender,
      address: "123 Main Street, Melbourne VIC 3000"
    )
    
    @mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    @mortgage.mortgage_lenders.create!(lender: @lender, active: true)
  end
  
  test "mortgage contract has user relationships" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Test Contract",
      content: "Test content",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    assert_equal @admin, contract.created_by
    assert_equal @customer, contract.primary_user
    assert_equal @mortgage, contract.mortgage
  end
  
  test "placeholder substitution with real user data" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Placeholder Test",
      content: "Customer: {{primary_user_full_name}}\nAddress: {{primary_user_address}}\nLender: {{lender_name}}\nLender Address: {{lender_address}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    rendered = contract.rendered_content
    
    # Should substitute primary user data
    assert_includes rendered, "John Smith"
    assert_includes rendered, "123 Main Street, Melbourne VIC 3000"
    
    # Should substitute lender data from mortgage relationships
    assert_includes rendered, "Futureproof Financial Group"
    assert_includes rendered, "456 Collins Street, Melbourne VIC 3000"
    
    # Should not contain placeholder syntax
    assert_not_includes rendered, "{{primary_user_full_name}}"
    assert_not_includes rendered, "{{lender_name}}"
  end
  
  test "placeholder substitution with sample data for preview" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Preview Test",
      content: "Customer: {{primary_user_full_name}}\nLender: {{lender_name}}",
      is_draft: true,
      created_by: @admin
      # No primary_user set
    )
    
    preview_content = contract.rendered_preview_content
    
    # Should use sample data
    assert_includes preview_content, "John Smith"
    assert_includes preview_content, "Futureproof Financial Group"
    assert_not_includes preview_content, "{{primary_user_full_name}}"
  end
  
  test "placeholder substitution handles missing associations" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Missing Data Test", 
      content: "Customer: {{primary_user_full_name}}\nAddress: {{primary_user_address}}",
      is_draft: true,
      created_by: @admin
      # No primary_user set
    )
    
    rendered = contract.rendered_content
    
    # Should leave placeholders when no data available
    assert_includes rendered, "{{primary_user_full_name}}"
    assert_includes rendered, "{{primary_user_address}}"
  end
  
  test "additional users can be associated through join table" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Multi-User Test",
      content: "Test content",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    other_user = User.create!(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      password: "password123", 
      password_confirmation: "password123",
      admin: false,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      lender: @lender
    )
    
    # Add through association
    contract.additional_users << other_user
    
    assert_includes contract.additional_users, other_user
    assert_equal 1, contract.mortgage_contract_users.count
  end
  
  test "user model has correct mortgage contract relationships" do
    contract1 = @mortgage.mortgage_contracts.create!(
      title: "Created Contract",
      content: "Test",
      is_draft: true,
      created_by: @admin
    )
    
    contract2 = @mortgage.mortgage_contracts.create!(
      title: "Primary Contract",
      content: "Test",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    # Admin should have created contracts
    assert_includes @admin.created_mortgage_contracts, contract1
    assert_includes @admin.created_mortgage_contracts, contract2
    
    # Customer should have primary contracts
    assert_includes @customer.primary_mortgage_contracts, contract2
    assert_not_includes @customer.primary_mortgage_contracts, contract1
  end
  
  test "contract workflow maintains user relationships" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Workflow Test",
      content: "Customer: {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    # Publish
    contract.update!(is_draft: false)
    assert contract.published?
    assert_equal @customer, contract.primary_user
    
    # Activate
    contract.update!(is_active: true)
    assert contract.is_active?
    assert_equal @customer, contract.primary_user
  end
  
  test "default contract template includes new agreement structure" do
    default_contract = MortgageContract.create_default
    
    # Should include new agreement parties section
    assert_includes default_contract.content, "## 1. Agreement Parties"
    assert_includes default_contract.content, "**The Customer (Borrower):**"
    assert_includes default_contract.content, "**The Lender:**"
    
    # Should include placeholders
    assert_includes default_contract.content, "{{primary_user_full_name}}"
    assert_includes default_contract.content, "{{primary_user_address}}"
    assert_includes default_contract.content, "{{lender_name}}"
    assert_includes default_contract.content, "{{lender_address}}"
    
    # Should include signature section
    assert_includes default_contract.content, "## 9. Agreement Execution"
    assert_includes default_contract.content, "Signature: _________________________"
  end
  
  test "substitute_placeholders method works with custom substitutions" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Custom Substitution Test",
      content: "Customer: {{primary_user_full_name}}\nCustom: {{custom_field}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    custom_substitutions = {
      'custom_field' => 'Custom Value',
      'primary_user_full_name' => 'Override Name'  # Should override default
    }
    
    result = contract.substitute_placeholders(contract.content, custom_substitutions)
    
    assert_includes result, "Override Name"  # Custom override
    assert_includes result, "Custom Value"  # Custom field
    assert_not_includes result, "John Smith"  # Original value overridden
  end
end