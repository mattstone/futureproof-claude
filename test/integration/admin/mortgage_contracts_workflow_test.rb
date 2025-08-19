require 'test_helper'

class Admin::MortgageContractsWorkflowTest < ActionDispatch::IntegrationTest
  setup do
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
      name: "Test Interest Only Mortgage",
      mortgage_type: :interest_only,
      lvr: 80.0
    )
  end
  
  test "complete mortgage contract workflow from creation to activation" do
    sign_in @admin
    
    # Step 1: Create new mortgage contract
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :success
    assert_select "h2", text: "Create New Mortgage Contract"
    assert_select ".contract-editor-layout", count: 1
    assert_select ".markup-preview", count: 1
    
    contract_params = {
      mortgage_contract: {
        title: "Comprehensive Test Contract",
        content: build_test_contract_content
      }
    }
    
    assert_difference -> { MortgageContract.count }, 1 do
      post admin_mortgage_mortgage_contracts_path(@mortgage), params: contract_params
    end
    
    contract = MortgageContract.last
    assert_equal "Comprehensive Test Contract", contract.title
    assert_equal @mortgage, contract.mortgage
    assert contract.draft?
    assert_not contract.is_active?
    assert_equal @admin, contract.created_by
    
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract created successfully/
    
    # Step 2: Edit the contract
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_response :success
    assert_select ".contract-editor-layout", count: 1
    assert_select "textarea[name='mortgage_contract[content]']"
    
    updated_content = contract.content + "\n\n## Additional Terms\n\nAdded during editing."
    
    patch admin_mortgage_mortgage_contract_path(@mortgage, contract), params: {
      mortgage_contract: {
        title: "Updated Test Contract",
        content: updated_content
      }
    }
    
    contract.reload
    assert_equal "Updated Test Contract", contract.title
    assert contract.content.include?("Additional Terms")
    assert contract.draft?
    
    # Step 3: Publish the contract
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    contract.reload
    assert_not contract.draft?
    assert_not contract.is_active?
    
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract published successfully/
    
    # Step 4: Activate the contract
    patch activate_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    contract.reload
    assert_not contract.draft?
    assert contract.is_active?
    
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract activated successfully/
    
    # Step 5: Try to edit published contract (should create new version)
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, contract, create_new_version: true)
    assert_response :success
    assert_select ".version-info", text: /Editing Published Contract/
    
    # Create new version
    new_version_content = "## Version 2\n\nThis is the second version of the contract."
    
    assert_difference -> { MortgageContract.count }, 1 do
      patch admin_mortgage_mortgage_contract_path(@mortgage, contract), params: {
        mortgage_contract: {
          title: "Version 2 Contract",
          content: new_version_content
        }
      }
    end
    
    new_version = MortgageContract.order(:version).last
    assert_equal contract.version + 1, new_version.version
    assert new_version.draft?
    assert_not new_version.is_active?
    assert_equal @mortgage, new_version.mortgage
    
    # Original version should remain unchanged
    contract.reload
    assert_not contract.draft?
    assert contract.is_active?
    assert_not contract.content.include?("Version 2")
  end
  
  test "mortgage contract preview endpoint works correctly" do
    sign_in @admin
    
    preview_params = {
      mortgage_contract: {
        title: "Preview Test Contract",
        content: build_test_contract_content
      }
    }
    
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: preview_params
    assert_response :success
    
    # Should render contract content as HTML
    assert_select "section.legal-section"
    assert_select "h2", text: "1. Loan Agreement Details"
    assert_select ".loan-details"
    assert_select ".contact-info"
    assert_select "strong", text: "Lender:"
  end
  
  test "mortgage contract index shows proper categorization" do
    # Create contracts in different states
    draft_contract = @mortgage.mortgage_contracts.create!(
      title: "Draft Contract",
      content: "## Draft\n\nThis is a draft.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
    
    published_contract = @mortgage.mortgage_contracts.create!(
      title: "Published Contract", 
      content: "## Published\n\nThis is published.",
      is_draft: false,
      is_active: false,
      created_by: @admin
    )
    
    active_contract = @mortgage.mortgage_contracts.create!(
      title: "Active Contract",
      content: "## Active\n\nThis is active.",
      is_draft: false,
      is_active: true,
      created_by: @admin
    )
    
    sign_in @admin
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :success
    
    # Should show tab structure
    assert_select ".contract-tabs"
    assert_select ".tab-link", text: "Published Contracts"
    assert_select ".tab-link", text: "Draft Contracts"
    
    # Published tab should show published and active contracts
    assert_select "#published-tab .admin-table tbody tr", count: 2
    assert_select "#published-tab", text: /Published Contract/
    assert_select "#published-tab", text: /Active Contract/
    assert_select "#published-tab .admin-badge", text: "Active"
    assert_select "#published-tab .admin-badge", text: "Published"
    
    # Draft tab should show draft contracts
    assert_select "#drafts-tab .admin-table tbody tr", count: 1
    assert_select "#drafts-tab", text: /Draft Contract/
    assert_select "#drafts-tab .admin-badge", text: "Draft"
  end
  
  test "mortgage contract show page displays all information correctly" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Detailed Test Contract",
      content: build_test_contract_content,
      is_draft: false,
      is_active: true,
      created_by: @admin
    )
    
    sign_in @admin
    get admin_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_response :success
    
    # Should show contract metadata
    assert_select "h2", text: contract.title
    assert_select ".admin-badge", text: "Active"
    assert_select ".meta-item", text: /Version.*#{contract.version}/
    assert_select ".meta-item", text: /Created By.*#{@admin.email}/
    
    # Should show rendered content
    assert_select ".contract-preview"
    assert_select ".legal-section"
    assert_select "h2", text: "1. Loan Agreement Details"
    
    # Should show appropriate action buttons for active contract
    assert_select "a", text: "Edit (New Version)"
    assert_select "a", text: "← Back to Contracts"
  end
  
  test "access control prevents non-futureproof admins from accessing mortgage contracts" do
    # Create external lender admin
    external_lender = Lender.create!(
      name: "External Lender",
      contact_email: "contact@external.com",
      lender_type: :external
    )
    
    external_admin = User.create!(
      first_name: "External",
      last_name: "Admin",
      email: "external@example.com",
      password: "password123", 
      password_confirmation: "password123",
      admin: true,
      lender: external_lender,
      terms_accepted: true,
      confirmed_at: 1.day.ago
    )
    
    contract = @mortgage.mortgage_contracts.create!(
      title: "Protected Contract",
      content: "## Protected\n\nThis should not be accessible.",
      is_draft: true,
      created_by: @admin
    )
    
    sign_in external_admin
    
    # Should not be able to access mortgage contracts
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :redirect
    
    get admin_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_response :redirect
    
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :redirect
  end
  
  test "contract deletion works for draft contracts only" do
    draft_contract = @mortgage.mortgage_contracts.create!(
      title: "Draft to Delete",
      content: "## Draft\n\nThis will be deleted.",
      is_draft: true,
      created_by: @admin
    )
    
    published_contract = @mortgage.mortgage_contracts.create!(
      title: "Published Contract",
      content: "## Published\n\nThis cannot be deleted.",
      is_draft: false,
      created_by: @admin
    )
    
    sign_in @admin
    
    # Should be able to delete draft contract
    assert_difference -> { MortgageContract.count }, -1 do
      delete admin_mortgage_mortgage_contract_path(@mortgage, draft_contract)
    end
    
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract deleted successfully/
    
    # Published contracts should not have delete option in interface
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_select "#published-tab" do
      assert_select "a", text: "View"
      assert_select "a", text: "Edit (New Version)"
      assert_select "a", text: "Activate"
      assert_select "a", { text: "Delete", count: 0 }
    end
  end
  
  test "contract versioning maintains proper sequence" do
    sign_in @admin
    
    # Create initial contract
    post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Version 1",
        content: "## Version 1\n\nFirst version."
      }
    }
    
    v1 = MortgageContract.last
    assert_equal 1, v1.version
    
    # Publish and edit to create version 2
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, v1)
    v1.reload
    
    # Edit published contract creates new version
    patch admin_mortgage_mortgage_contract_path(@mortgage, v1), params: {
      mortgage_contract: {
        title: "Version 2",
        content: "## Version 2\n\nSecond version."
      }
    }
    
    v2 = MortgageContract.order(:version).last
    assert_equal 2, v2.version
    assert_equal @mortgage, v2.mortgage
    
    # Publish v2 and create v3
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, v2)
    v2.reload
    
    patch admin_mortgage_mortgage_contract_path(@mortgage, v2), params: {
      mortgage_contract: {
        title: "Version 3", 
        content: "## Version 3\n\nThird version."
      }
    }
    
    v3 = MortgageContract.order(:version).last
    assert_equal 3, v3.version
    
    # All versions should belong to the same mortgage
    assert_equal @mortgage, v1.mortgage
    assert_equal @mortgage, v2.mortgage
    assert_equal @mortgage, v3.mortgage
    
    # Only one can be active at a time
    patch activate_admin_mortgage_mortgage_contract_path(@mortgage, v3)
    
    [v1, v2, v3].each(&:reload)
    assert_not v1.is_active?
    assert_not v2.is_active?
    assert v3.is_active?
  end
  
  test "markup rendering produces expected HTML structure" do
    content = build_test_contract_content
    
    contract = @mortgage.mortgage_contracts.create!(
      title: "Markup Test Contract",
      content: content,
      created_by: @admin
    )
    
    rendered_html = contract.rendered_content
    
    # Should contain proper HTML structure
    assert rendered_html.include?('<section class="legal-section">')
    assert rendered_html.include?('<h2>1. Loan Agreement Details</h2>')
    assert rendered_html.include?('<h3>2.1 Equity Protection</h3>')
    assert rendered_html.include?('<div class="loan-details">')
    assert rendered_html.include?('<div class="contact-info">')
    assert rendered_html.include?('<ul>')
    assert rendered_html.include?('<li>')
    assert rendered_html.include?('<strong>')
    
    # Should not contain script tags or dangerous content
    assert_not rendered_html.include?('<script>')
    assert_not rendered_html.include?('javascript:')
    assert_not rendered_html.include?('onclick=')
  end
  
  private
  
  def build_test_contract_content
    <<~CONTENT
      ## 1. Loan Agreement Details
      
      This Equity Preservation Mortgage Agreement ("Agreement") is entered into between:
      
      **Lender:** Futureproof Financial Group Limited
      **Borrower:** [Borrower Name]
      **Property:** [Property Address]
      **Loan Amount:** [Loan Amount]
      **Loan-to-Value Ratio:** [LVR]%
      
      ## 2. Equity Preservation Features
      
      ### 2.1 Equity Protection
      
      This mortgage includes equity preservation features designed to protect your home's value:
      
      - **Market Value Protection:** Your loan amount will not exceed the original LVR
      - **Equity Sharing:** You maintain full ownership and benefit from value increases
      - **No Negative Equity:** You will never owe more than your property is worth
      
      ### 2.2 Interest Rate Structure
      
      - **Initial Rate:** [Interest Rate]% per annum
      - **Rate Type:** [Fixed/Variable]
      - **Rate Review:** [Review Terms]
      
      ## 3. Contact Information
      
      **Contact Information:**
      Lender: Futureproof Financial Group Limited
      Email: legal@futureprooffinancial.app
      Phone: 1300 XXX XXX
      Address: [Lender Address]
    CONTENT
  end
end