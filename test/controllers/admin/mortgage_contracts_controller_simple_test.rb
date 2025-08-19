require 'test_helper'

class Admin::MortgageContractsControllerSimpleTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  # Don't load fixtures to avoid foreign key issues
  fixtures :none
  
  setup do
    # Create test data without fixtures
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE users RESTART IDENTITY CASCADE")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE lenders RESTART IDENTITY CASCADE")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE mortgages RESTART IDENTITY CASCADE")
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE mortgage_contracts RESTART IDENTITY CASCADE")
    
    # Create futureproof admin user
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
    
    # Create lender for the admin
    @lender = Lender.create!(
      name: "Futureproof Financial Group",
      contact_email: "contact@futureproof.app",
      lender_type: :futureproof
    )
    
    @admin.update!(lender: @lender)
    
    # Create test mortgage
    @mortgage = Mortgage.create!(
      name: "Test Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
    
    # Create test mortgage contract
    @mortgage_contract = @mortgage.mortgage_contracts.create!(
      title: "Test Contract",
      content: "## Test\n\nTest content.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    
    sign_in @admin
  end
  
  test "can access mortgage contracts index" do
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :success
    assert_includes @response.body, "Published Contracts"
    assert_includes @response.body, "Draft Contracts"
  end
  
  test "can view mortgage contract" do
    get admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    assert_includes @response.body, @mortgage_contract.title
  end
  
  test "can access new mortgage contract form" do
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :success
    assert_includes @response.body, "Create New Mortgage Contract"
    assert_includes @response.body, "Live Preview"
  end
  
  test "can access edit mortgage contract form with live preview" do
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    assert_includes @response.body, "Edit Contract"
    assert_includes @response.body, "Live Preview"
    assert_includes @response.body, "contract-editor-layout"
    assert_includes @response.body, "markup-preview"
  end
  
  test "can create new mortgage contract" do
    contract_params = {
      mortgage_contract: {
        title: "New Test Contract",
        content: "## New Contract\n\nNew content."
      }
    }
    
    assert_difference -> { MortgageContract.count }, 1 do
      post admin_mortgage_mortgage_contracts_path(@mortgage), params: contract_params
    end
    
    new_contract = MortgageContract.last
    assert_equal "New Test Contract", new_contract.title
    assert_equal @mortgage, new_contract.mortgage
    assert new_contract.draft?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "can update mortgage contract" do
    patch admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract), params: {
      mortgage_contract: {
        title: "Updated Contract",
        content: "## Updated\n\nUpdated content."
      }
    }
    
    @mortgage_contract.reload
    assert_equal "Updated Contract", @mortgage_contract.title
    assert_includes @mortgage_contract.content, "Updated content"
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "can publish mortgage contract" do
    assert @mortgage_contract.draft?
    
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    
    @mortgage_contract.reload
    assert_not @mortgage_contract.draft?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "can activate mortgage contract" do
    @mortgage_contract.update!(is_draft: false)
    
    patch activate_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    
    @mortgage_contract.reload
    assert @mortgage_contract.is_active?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "preview endpoint works" do
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Preview Contract",
        content: "## Preview Test\n\n**Bold text** and regular text."
      }
    }
    
    assert_response :success
    assert_includes @response.body, "<h2>Preview Test</h2>"
    assert_includes @response.body, "<strong>Bold text</strong>"
  end
  
  test "live preview JavaScript is included" do
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Check for live preview JavaScript
    assert_includes @response.body, "initializeMortgageContractPreview"
    assert_includes @response.body, "markupToHtml"
    assert_includes @response.body, "updatePreviewInstant"
    assert_includes @response.body, "addEventListener('input'"
  end
  
  test "live preview CSS is included" do
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    # Check for live preview CSS
    assert_includes @response.body, ".contract-editor-layout"
    assert_includes @response.body, ".contract-preview-column"
    assert_includes @response.body, ".markup-preview"
    assert_includes @response.body, "grid-template-columns: 1fr 1fr"
  end
  
  test "form validation works" do
    post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "", # Required field
        content: "" # Required field
      }
    }
    
    assert_response :unprocessable_entity
    assert_includes @response.body, "can't be blank"
  end
  
  test "contracts are properly scoped to mortgage" do
    other_mortgage = Mortgage.create!(
      name: "Other Mortgage",
      mortgage_type: :principal_and_interest,
      lvr: 75.0
    )
    
    other_contract = other_mortgage.mortgage_contracts.create!(
      title: "Other Contract",
      content: "## Other\n\nOther content.",
      is_draft: true,
      created_by: @admin
    )
    
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :success
    
    # Should only show contracts for the specified mortgage
    assert_includes @response.body, @mortgage_contract.title
    assert_not_includes @response.body, other_contract.title
  end
end