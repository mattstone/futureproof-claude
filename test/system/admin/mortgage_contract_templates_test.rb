require 'application_system_test_case'

class Admin::MortgageContractTemplatesTest < ApplicationSystemTestCase
  # Don't load fixtures to avoid foreign key issues
  fixtures :none
  setup do
    # Create test data without fixtures
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
      address: "Admin Office, 456 Collins Street, Melbourne VIC 3000"
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
    
    # Create mortgage-lender relationship
    @mortgage.mortgage_lenders.create!(lender: @lender, active: true)
    
    sign_in @admin
  end
  
  test "can create new mortgage contract template with placeholders" do
    visit new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    assert_selector "h2", text: "Create New Mortgage Contract"
    assert_selector ".contract-editor-layout"
    assert_selector ".contract-preview-column"
    assert_selector "#markup-preview-standalone"
    
    # Fill in contract details
    fill_in "Title", with: "Test Agreement Template"
    
    contract_content = <<~CONTENT
      ## 1. Agreement Parties
      
      This mortgage agreement is between:
      
      **The Customer:**
      {{primary_user_full_name}}
      {{primary_user_address}}
      
      **The Lender:**
      {{lender_name}}
      {{lender_address}}
      
      ## 2. Agreement Terms
      
      This is a paperless contract template for testing placeholder substitution.
    CONTENT
    
    fill_in "Content", with: contract_content
    
    # Verify live preview shows substituted placeholders
    within "#markup-preview-standalone" do
      assert_text "John Smith"
      assert_text "123 Main Street, Melbourne VIC 3000"
      assert_text "Futureproof Financial Group"
      assert_text "456 Collins Street, Melbourne VIC 3000"
      assert_selector "h2", text: "1. Agreement Parties"
      assert_selector "h2", text: "2. Agreement Terms"
    end
    
    click_button "Create Contract"
    
    # Should redirect and show success
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_text "Contract was successfully created"
    
    # Verify contract was created with correct data
    contract = MortgageContract.last
    assert_equal "Test Agreement Template", contract.title
    assert_includes contract.content, "{{primary_user_full_name}}"
    assert_includes contract.content, "{{lender_name}}"
    assert contract.draft?
    assert_equal @mortgage, contract.mortgage
  end
  
  test "can edit mortgage contract template and see placeholder substitution" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Existing Template",
      content: "## Test\n\nCustomer: {{primary_user_full_name}}\nLender: {{lender_name}}",
      is_draft: true,
      created_by: @admin
    )
    
    visit edit_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    assert_selector "h2", text: "Edit Contract"
    assert_field "Title", with: "Existing Template"
    
    # Verify live preview shows substituted placeholders
    within "#markup-preview-standalone" do
      assert_text "John Smith"
      assert_text "Futureproof Financial Group"
    end
    
    # Update the template
    fill_in "Title", with: "Updated Template"
    
    new_content = <<~CONTENT
      ## 1. Updated Agreement
      
      Agreement between {{primary_user_full_name}} and {{lender_name}}.
      
      Customer Address: {{primary_user_address}}
      Lender Address: {{lender_address}}
    CONTENT
    
    fill_in "Content", with: new_content
    
    # Verify updated preview
    within "#markup-preview-standalone" do
      assert_text "Updated Agreement"
      assert_text "123 Main Street, Melbourne VIC 3000"
      assert_text "456 Collins Street, Melbourne VIC 3000"
    end
    
    click_button "Update Contract"
    
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_text "Contract was successfully updated"
    
    # Verify changes were saved
    contract.reload
    assert_equal "Updated Template", contract.title
    assert_includes contract.content, "{{primary_user_address}}"
    assert_includes contract.content, "{{lender_address}}"
  end
  
  test "can view mortgage contract template with rendered placeholders" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "View Test Template",
      content: "## Agreement\n\n**Customer:** {{primary_user_full_name}}\n**Address:** {{primary_user_address}}\n**Lender:** {{lender_name}}",
      is_draft: false,
      is_active: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    visit admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    assert_selector "h1", text: "View Test Template"
    
    # Verify rendered content shows actual values when primary_user is set
    within ".rendered-content" do
      assert_text "John Smith"
      assert_text "123 Main Street, Melbourne VIC 3000"
      assert_text "Futureproof Financial Group"
    end
  end
  
  test "can publish and activate mortgage contract template" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Draft Template",
      content: "## Test\n\nCustomer: {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin
    )
    
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Should show as draft
    within ".draft-contracts" do
      assert_text "Draft Template"
      assert_selector ".status-badge", text: "Draft"
    end
    
    # Publish the contract
    click_link "View", match: :first
    click_button "Publish Contract"
    
    assert_text "Contract was successfully published"
    
    # Should now show as published
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    within ".published-contracts" do
      assert_text "Draft Template"
      assert_selector ".status-badge", text: "Published"
    end
    
    # Activate the contract
    click_link "View", match: :first
    click_button "Activate Contract"
    
    assert_text "Contract was successfully activated"
    
    # Verify it's now active
    contract.reload
    assert contract.is_active?
    assert_not contract.is_draft?
  end
  
  test "placeholder substitution works with different user data" do
    # Create another customer with different data
    other_customer = User.create!(
      first_name: "Jane",
      last_name: "Doe", 
      email: "jane@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: false,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      lender: @lender,
      address: "789 Oak Avenue, Sydney NSW 2000"
    )
    
    contract = @mortgage.mortgage_contracts.create!(
      title: "Multi-User Template",
      content: "Customer: {{primary_user_full_name}} at {{primary_user_address}}",
      is_draft: false,
      created_by: @admin,
      primary_user: other_customer
    )
    
    visit admin_mortgage_mortgage_contract_path(@mortgage, contract)
    
    # Should show Jane's data, not John's
    within ".rendered-content" do
      assert_text "Jane Doe"
      assert_text "789 Oak Avenue, Sydney NSW 2000"
      assert_no_text "John Smith"
      assert_no_text "123 Main Street"
    end
  end
  
  test "contract list shows template information correctly" do
    # Create contracts in different states
    draft_contract = @mortgage.mortgage_contracts.create!(
      title: "Draft Template",
      content: "Draft content with {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin
    )
    
    published_contract = @mortgage.mortgage_contracts.create!(
      title: "Published Template", 
      content: "Published content with {{lender_name}}",
      is_draft: false,
      is_active: false,
      created_by: @admin
    )
    
    active_contract = @mortgage.mortgage_contracts.create!(
      title: "Active Template",
      content: "Active content",
      is_draft: false,
      is_active: true,
      created_by: @admin
    )
    
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Check draft section
    within ".draft-contracts" do
      assert_text "Draft Template"
      assert_selector ".status-badge.status-warning", text: "Draft"
    end
    
    # Check published section  
    within ".published-contracts" do
      assert_text "Published Template"
      assert_selector ".status-badge.status-info", text: "Published"
      assert_text "Active Template"
      assert_selector ".status-badge.status-success", text: "Active"
    end
  end
  
  test "live preview updates instantly as user types placeholders" do
    visit new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    fill_in "Title", with: "Live Preview Test"
    
    # Start typing content with placeholders
    content_field = find("#mortgage_contract_content")
    content_field.fill_in with: "## Test\n\nCustomer: {{primary_user"
    
    # Preview should show partial placeholder as typed
    within "#markup-preview-standalone" do
      assert_text "{{primary_user"
    end
    
    # Complete the placeholder
    content_field.fill_in with: "## Test\n\nCustomer: {{primary_user_full_name}}"
    
    # Should now show substituted value
    within "#markup-preview-standalone" do
      assert_text "John Smith"
      assert_no_text "{{primary_user_full_name}}"
    end
  end
  
  test "can delete mortgage contract template" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Template to Delete",
      content: "Test content",
      is_draft: true,
      created_by: @admin
    )
    
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    assert_text "Template to Delete"
    
    # Visit the contract view page
    click_link "View"
    
    # Delete the contract
    accept_confirm do
      click_button "Delete Contract"
    end
    
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_text "Contract was successfully deleted"
    assert_no_text "Template to Delete"
    
    # Verify it's actually deleted
    assert_not MortgageContract.exists?(contract.id)
  end
end