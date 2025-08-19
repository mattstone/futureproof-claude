require 'application_system_test_case'

class Admin::MortgageContractCrudSystemTest < ApplicationSystemTestCase
  self.use_transactional_tests = false
  
  def self.use_instantiated_fixtures
    false
  end
  
  def self.fixture_path
    nil
  end
  
  setup do
    # Create clean test data
    User.delete_all
    Lender.delete_all
    Mortgage.delete_all
    MortgageContract.delete_all
    
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
    
    sign_in @admin
  end
  
  test "complete CRUD workflow: create, read, update, publish, activate, delete" do
    # Step 1: Navigate to contracts index
    visit admin_mortgage_path(@mortgage)
    click_link "View All Contracts"
    
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_selector "h1", text: "Mortgage Contracts"
    
    # Should show empty state for drafts
    assert_text "No Draft Contracts Found"
    
    # Step 2: Create new contract
    click_link "Create New Contract"
    
    assert_current_path new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_selector "h2", text: "Create New Mortgage Contract"
    
    # Fill in form with placeholder content
    fill_in "Title", with: "CRUD Test Contract"
    
    contract_content = <<~CONTENT
      ## 1. Agreement Parties
      
      **The Customer:**
      {{primary_user_full_name}}
      {{primary_user_address}}
      
      **The Lender:**
      {{lender_name}}
      {{lender_address}}
      
      ## 2. Test Terms
      
      This is a test contract for CRUD testing.
      
      ### 2.1 Payment Terms
      
      - Monthly payments required
      - **Interest Rate:** 4.5%
      - **Loan Amount:** $500,000
      
      ## 3. Contact Information
      
      Lender: {{lender_name}}
      Email: contact@example.com
    CONTENT
    
    fill_in "Content", with: contract_content
    
    # Verify live preview is working
    within ".contract-preview-column" do
      assert_text "John Smith"
      assert_text "Futureproof Financial Group"
      assert_text "Agreement Parties"
      assert_text "Test Terms"
    end
    
    click_button "Create Contract (Draft)"
    
    # Should redirect to index
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_text "Mortgage Contract created successfully"
    
    # Step 3: Verify contract appears in drafts
    click_link "Draft Contracts"
    
    within "#drafts-tab" do
      assert_text "CRUD Test Contract"
      assert_selector ".admin-badge", text: "Draft"
    end
    
    # Step 4: View the contract
    within "#drafts-tab" do
      click_link "View"
    end
    
    contract = MortgageContract.last
    assert_current_path admin_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_text "CRUD Test Contract"
    assert_text "Agreement Parties"
    
    # Step 5: Edit the contract
    click_link "Edit Contract"
    
    assert_current_path edit_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    # Update title and content
    fill_in "Title", with: "Updated CRUD Test Contract"
    
    updated_content = <<~CONTENT
      ## 1. Updated Agreement Parties
      
      **The Customer:**
      {{primary_user_full_name}}
      {{primary_user_address}}
      
      **The Lender:**
      {{lender_name}}
      {{lender_address}}
      
      ## 2. Updated Terms
      
      This contract has been updated during CRUD testing.
      
      ### 2.1 New Payment Terms
      
      - **Updated Interest Rate:** 3.8%
      - **Updated Loan Amount:** $600,000
    CONTENT
    
    fill_in "Content", with: updated_content
    
    click_button "Update Contract"
    
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_text "Mortgage Contract updated successfully"
    
    # Step 6: Publish the contract
    click_link "Draft Contracts"
    
    within "#drafts-tab" do
      assert_text "Updated CRUD Test Contract"
      
      accept_confirm do
        click_link "Publish"
      end
    end
    
    assert_text "Mortgage Contract published successfully"
    
    # Step 7: Verify contract moved to published
    click_link "Published Contracts"
    
    within "#published-tab" do
      assert_text "Updated CRUD Test Contract"
      assert_selector ".admin-badge", text: "Published"
    end
    
    # Step 8: Activate the contract
    within "#published-tab" do
      accept_confirm do
        click_link "Activate"
      end
    end
    
    assert_text "Mortgage Contract activated successfully"
    
    # Verify it shows as active
    within "#published-tab" do
      assert_selector ".admin-badge", text: "Active"
      assert_selector ".active-row"
    end
    
    # Step 9: Create new version from published contract
    within "#published-tab" do
      click_link "Edit (New Version)"
    end
    
    fill_in "Title", with: "New Version Test Contract"
    click_button "Create New Version"
    
    assert_text "New draft version created successfully"
    
    # Step 10: Verify both versions exist
    click_link "Published Contracts"
    within "#published-tab" do
      assert_text "Updated CRUD Test Contract"
      assert_selector ".admin-badge", text: "Active"
    end
    
    click_link "Draft Contracts"
    within "#drafts-tab" do
      assert_text "New Version Test Contract"
      assert_selector ".admin-badge", text: "Draft"
    end
    
    # Step 11: Delete the draft contract
    within "#drafts-tab" do
      accept_confirm do
        click_link "Delete"
      end
    end
    
    assert_text "Mortgage Contract deleted successfully"
    
    # Verify draft is gone but published remains
    assert_text "No Draft Contracts Found"
    
    click_link "Published Contracts"
    within "#published-tab" do
      assert_text "Updated CRUD Test Contract"
    end
  end
  
  test "form validation works correctly" do
    visit new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    # Try to submit empty form
    click_button "Create Contract (Draft)"
    
    assert_text "can't be blank"
    
    # Fill in title but leave content empty
    fill_in "Title", with: "Test Contract"
    click_button "Create Contract (Draft)"
    
    assert_text "can't be blank"
    
    # Fill in minimal valid content
    fill_in "Content", with: "## Test\n\nMinimal content"
    click_button "Create Contract (Draft)"
    
    assert_text "Mortgage Contract created successfully"
  end
  
  test "preview functionality works" do
    visit new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    fill_in "Title", with: "Preview Test Contract"
    fill_in "Content", with: "## Test Section\n\n**Customer:** {{primary_user_full_name}}\n**Lender:** {{lender_name}}"
    
    # Test preview button (note: actual popup testing is complex in system tests)
    assert_selector "#preview-btn"
    
    # Verify the preview endpoint works directly
    contract_params = {
      mortgage_contract: {
        title: "Preview Test",
        content: "## Test\n\n**Customer:** {{primary_user_full_name}}"
      }
    }
    
    # This would test the preview endpoint
    page.execute_script(%{
      fetch('#{preview_admin_mortgage_mortgage_contracts_path(@mortgage)}', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify(#{contract_params.to_json})
      }).then(response => {
        if (response.ok) {
          document.body.setAttribute('data-preview-success', 'true');
        }
      });
    })
    
    # Give time for the request
    sleep 1
    
    # Check if preview request was successful (this is a simplified test)
    assert page.has_css?('body[data-preview-success="true"]', wait: 2)
  end
  
  test "user relationships work correctly" do
    # Create contract with primary user
    contract = @mortgage.mortgage_contracts.create!(
      title: "User Relationship Test",
      content: "Customer: {{primary_user_full_name}}\nAddress: {{primary_user_address}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    visit admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    # Should show substituted values
    within ".rendered-content" do
      assert_text "John Smith"
      assert_text "123 Main Street, Melbourne VIC 3000"
    end
  end
  
  test "navigation and breadcrumbs work correctly" do
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Test navigation to new contract
    click_link "Create New Contract"
    assert_current_path new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    # Test cancel navigation
    click_link "Cancel"
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Test back navigation
    click_link "← Back to Contracts"
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "tab switching works correctly" do
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Initially should show published tab
    assert_selector "#published-tab.active"
    assert_selector "#drafts-tab:not(.active)"
    
    # Click draft tab
    click_link "Draft Contracts"
    
    # Should switch to drafts
    assert_selector "#drafts-tab.active", wait: 1
    assert_selector "#published-tab:not(.active)"
    
    # Click back to published
    click_link "Published Contracts"
    
    assert_selector "#published-tab.active", wait: 1
    assert_selector "#drafts-tab:not(.active)"
  end
  
  test "contract versioning displays correctly" do
    # Create multiple versions
    v1 = @mortgage.mortgage_contracts.create!(
      title: "Version 1",
      content: "## Version 1\n\nFirst version",
      is_draft: false,
      is_active: true,
      created_by: @admin
    )
    
    v2 = @mortgage.mortgage_contracts.create!(
      title: "Version 2", 
      content: "## Version 2\n\nSecond version",
      is_draft: true,
      created_by: @admin
    )
    
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Check published contracts
    within "#published-tab" do
      assert_text "Version 1"
      assert_selector ".admin-badge", text: "1"
      assert_selector ".admin-badge", text: "Active"
    end
    
    # Check draft contracts
    click_link "Draft Contracts"
    within "#drafts-tab" do
      assert_text "Version 2"
      assert_selector ".admin-badge", text: "2"
      assert_selector ".admin-badge", text: "Draft"
    end
  end
end