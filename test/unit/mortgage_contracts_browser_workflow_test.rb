require 'test_helper'

class MortgageContractsBrowserWorkflowTest < ActiveSupport::TestCase
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
      confirmed_at: 1.day.ago
    )
    
    @lender = Lender.create!(
      name: "Futureproof Financial Group",
      contact_email: "contact@futureproof.app",
      lender_type: :futureproof
    )
    
    @admin.update!(lender: @lender)
    
    @mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
  end
  
  test "mortgage contract model relationships work correctly" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Test Contract",
      content: "## Test\n\nTest content.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    
    assert_equal @mortgage, contract.mortgage
    assert_equal @admin, contract.created_by
    assert contract.draft?
    assert_not contract.is_active?
    assert_equal 1, contract.version
  end
  
  test "mortgage contract workflow from draft to active" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Workflow Test Contract",
      content: "## Workflow Test\n\nThis tests the complete workflow.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    
    # Step 1: Create draft
    assert contract.draft?
    assert_not contract.published?
    assert_not contract.is_active?
    assert_equal "Draft", contract.status
    
    # Step 2: Publish
    contract.update!(is_draft: false)
    contract.reload
    
    assert_not contract.draft?
    assert contract.published?
    assert_not contract.is_active?
    assert_equal "Published", contract.status
    
    # Step 3: Activate
    contract.update!(is_active: true)
    contract.reload
    
    assert_not contract.draft?
    assert contract.published?
    assert contract.is_active?
    assert_equal "Active", contract.status
  end
  
  test "mortgage contract versioning works correctly" do
    # Create first version
    v1 = @mortgage.mortgage_contracts.create!(
      title: "Version 1",
      content: "## Version 1\n\nFirst version.",
      is_draft: true,
      created_by: @admin
    )
    
    assert_equal 1, v1.version
    
    # Publish v1
    v1.update!(is_draft: false, is_active: true)
    
    # Create second version
    v2 = @mortgage.mortgage_contracts.create!(
      title: "Version 2", 
      content: "## Version 2\n\nSecond version.",
      is_draft: true,
      created_by: @admin
    )
    
    assert_equal 2, v2.version
    assert_equal @mortgage, v2.mortgage
    
    # Both should belong to same mortgage
    assert_equal @mortgage, v1.mortgage
    assert_equal @mortgage, v2.mortgage
    
    # Only one can be active
    v2.update!(is_draft: false, is_active: true)
    v1.reload
    
    assert_not v1.is_active?
    assert v2.is_active?
  end
  
  test "mortgage contract markup rendering works" do
    content = <<~CONTENT
      ## 1. Loan Agreement
      
      This is a test contract.
      
      **Loan Amount:** $500,000
      **Interest Rate:** 4.5%
      
      ### 1.1 Terms
      
      - Monthly payments required
      - **No penalty** for early repayment
      - Property insurance mandatory
      
      ## 2. Contact Information
      
      Lender: Test Lender
      Email: test@example.com
      Phone: 1-800-TEST
    CONTENT
    
    contract = @mortgage.mortgage_contracts.create!(
      title: "Markup Test",
      content: content,
      is_draft: true,
      created_by: @admin
    )
    
    rendered = contract.rendered_content
    
    # Should contain proper HTML structure
    assert_includes rendered, '<section class="legal-section">'
    assert_includes rendered, '<h2>1. Loan Agreement</h2>'
    assert_includes rendered, '<h3>1.1 Terms</h3>'
    assert_includes rendered, '<div class="loan-details">'
    assert_includes rendered, '<div class="contact-info">'
    assert_includes rendered, '<ul>'
    assert_includes rendered, '<li>'
    assert_includes rendered, '<strong>'
    
    # Should not contain dangerous content
    assert_not_includes rendered, '<script>'
    assert_not_includes rendered, 'javascript:'
  end
  
  test "mortgage contract scoping works correctly" do
    # Create another mortgage
    other_mortgage = Mortgage.create!(
      name: "Other Mortgage",
      mortgage_type: :principal_and_interest,
      lvr: 75.0
    )
    
    # Create contracts for each mortgage
    contract1 = @mortgage.mortgage_contracts.create!(
      title: "Contract 1",
      content: "## Contract 1\n\nFirst mortgage contract.",
      is_draft: true,
      created_by: @admin
    )
    
    contract2 = other_mortgage.mortgage_contracts.create!(
      title: "Contract 2",
      content: "## Contract 2\n\nSecond mortgage contract.",
      is_draft: true,
      created_by: @admin
    )
    
    # Each mortgage should only see its own contracts
    assert_equal [contract1], @mortgage.mortgage_contracts.to_a
    assert_equal [contract2], other_mortgage.mortgage_contracts.to_a
    
    # Contracts should belong to correct mortgages
    assert_equal @mortgage, contract1.mortgage
    assert_equal other_mortgage, contract2.mortgage
  end
  
  test "mortgage contract change tracking works" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Change Tracking Test",
      content: "## Original\n\nOriginal content.",
      is_draft: true,
      created_by: @admin
    )
    
    # Should have creation version
    assert_equal 1, contract.mortgage_contract_versions.count
    version = contract.mortgage_contract_versions.first
    assert_equal 'created', version.action
    assert_equal @admin, version.user
  end
  
  test "mortgage contract status helpers work correctly" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Status Test",
      content: "## Status Test\n\nTesting status helpers.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    
    # Test draft status
    assert contract.draft?
    assert_not contract.published?
    assert_equal "Draft", contract.status
    assert_equal "warning", contract.status_color
    
    # Test published status
    contract.update!(is_draft: false)
    assert_not contract.draft?
    assert contract.published?
    assert_equal "Published", contract.status
    assert_equal "info", contract.status_color
    
    # Test active status
    contract.update!(is_active: true)
    assert contract.published?
    assert_equal "Active", contract.status
    assert_equal "success", contract.status_color
  end
  
  test "mortgage contract unique version constraint works" do
    # Create first contract
    contract1 = @mortgage.mortgage_contracts.create!(
      title: "Version 1",
      content: "## Test\n\nFirst contract.",
      is_draft: true,
      created_by: @admin
    )
    
    assert_equal 1, contract1.version
    
    # Try to create another contract with same version should auto-increment
    contract2 = @mortgage.mortgage_contracts.create!(
      title: "Version 2",
      content: "## Test\n\nSecond contract.",
      is_draft: true,
      created_by: @admin
    )
    
    assert_equal 2, contract2.version
    assert_not_equal contract1.version, contract2.version
  end
  
  test "mortgage contract validation works" do
    # Should require title
    contract = @mortgage.mortgage_contracts.build(
      content: "## Test\n\nTest content.",
      is_draft: true,
      created_by: @admin
    )
    
    assert_not contract.valid?
    assert_includes contract.errors[:title], "can't be blank"
    
    # Should require content
    contract.title = "Test Contract"
    contract.content = ""
    
    assert_not contract.valid?
    assert_includes contract.errors[:content], "can't be blank"
    
    # Should be valid with all required fields
    contract.content = "## Test\n\nTest content."
    assert contract.valid?
  end
end