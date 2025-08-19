require 'application_system_test_case'

class Admin::MortgageContractsBrowserTest < ApplicationSystemTestCase
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
    
    # Create existing mortgage contract for testing
    @existing_contract = @mortgage.mortgage_contracts.create!(
      title: "Existing Test Contract",
      content: "## Existing Contract\n\nThis is an existing contract for testing.",
      is_draft: true,
      is_active: false,
      created_by: @admin
    )
  end
  
  test "admin can navigate to mortgage contracts from mortgage show page" do
    sign_in_admin
    
    # Navigate to mortgages
    visit admin_mortgages_path
    assert page.has_text?("Mortgages")
    
    # Click on the test mortgage
    click_link "View"
    assert page.has_text?(@mortgage.name)
    
    # Should see mortgage contracts section
    assert page.has_text?("Mortgage Contracts")
    assert page.has_text?("Manage contract documents for this mortgage")
    
    # Should show existing contract
    assert page.has_text?(@existing_contract.title)
    assert page.has_text?("v#{@existing_contract.version}")
    assert page.has_text?("Draft")
    
    # Should have create contract button
    assert page.has_link?("New Contract")
    assert page.has_link?("View All Contracts")
  end
  
  test "admin can create new mortgage contract with live preview" do
    sign_in_admin
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Click create new contract
    click_link "New Contract"
    assert page.has_text?("Create New Mortgage Contract")
    
    # Should see the form and live preview side by side
    assert page.has_selector?(".contract-editor-layout")
    assert page.has_selector?(".contract-form-column")
    assert page.has_selector?(".contract-preview-column")
    
    # Should see live preview panel
    assert page.has_text?("Live Preview")
    assert page.has_text?("See your changes in real-time")
    assert page.has_text?("Contract preview will appear here as you type...")
    
    # Fill in the form
    fill_in "Title", with: "New Test Contract"
    
    # Type content and watch live preview update
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    
    # Type first section
    content_textarea.send_keys("## 1. Loan Agreement\n\nThis is a test contract.")
    
    # Give JS time to update preview
    sleep 0.5
    
    # Should see live preview update
    within(".markup-preview") do
      assert page.has_selector?("h2", text: "1. Loan Agreement")
      assert page.has_text?("This is a test contract.")
    end
    
    # Add more complex content to test markup
    content_textarea.send_keys("\n\n### 1.1 Loan Details\n\n")
    content_textarea.send_keys("**Loan Amount:** $500,000\n")
    content_textarea.send_keys("**Interest Rate:** 4.5%\n\n")
    content_textarea.send_keys("## 2. Terms and Conditions\n\n")
    content_textarea.send_keys("- Monthly payments due on 1st of each month\n")
    content_textarea.send_keys("- **Early repayment** allowed without penalty\n")
    content_textarea.send_keys("- Property insurance required\n\n")
    content_textarea.send_keys("## 3. Contact Information\n\n")
    content_textarea.send_keys("Lender: Futureproof Financial Group\n")
    content_textarea.send_keys("Email: legal@futureproof.app\n")
    content_textarea.send_keys("Phone: 1300 XXX XXX")
    
    # Give JS time to update preview
    sleep 1
    
    # Verify live preview shows all content properly formatted
    within(".markup-preview") do
      # Section headings
      assert page.has_selector?("h2", text: "1. Loan Agreement")
      assert page.has_selector?("h2", text: "2. Terms and Conditions") 
      assert page.has_selector?("h2", text: "3. Contact Information")
      assert page.has_selector?("h3", text: "1.1 Loan Details")
      
      # Loan details formatting
      assert page.has_selector?(".loan-details")
      assert page.has_text?("Loan Amount:")
      assert page.has_text?("$500,000")
      assert page.has_text?("Interest Rate:")
      assert page.has_text?("4.5%")
      
      # List formatting
      assert page.has_selector?("ul")
      assert page.has_selector?("li", text: "Monthly payments due on 1st of each month")
      assert page.has_selector?("strong", text: "Early repayment")
      
      # Contact info formatting
      assert page.has_selector?(".contact-info")
      assert page.has_text?("Futureproof Financial Group")
      assert page.has_text?("legal@futureproof.app")
    end
    
    # Submit the form
    click_button "Create Contract (Draft)"
    
    # Should redirect to contracts index
    assert page.has_text?("Mortgage Contract created successfully")
    assert page.has_text?("New Test Contract")
    
    # Verify the contract was created correctly
    new_contract = MortgageContract.last
    assert_equal "New Test Contract", new_contract.title
    assert_equal @mortgage, new_contract.mortgage
    assert new_contract.draft?
    assert_not new_contract.is_active?
  end
  
  test "admin can edit mortgage contract with live preview updates" do
    sign_in_admin
    visit admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Click edit button
    click_link "Edit Contract"
    assert page.has_text?("Edit Contract")
    
    # Should see live preview with existing content
    within(".markup-preview") do
      assert page.has_selector?("h2", text: "Existing Contract")
      assert page.has_text?("This is an existing contract for testing.")
    end
    
    # Modify the content
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    content_textarea.send_keys("\n\n### New Section\n\nAdded during editing.")
    
    # Give JS time to update
    sleep 0.5
    
    # Should see updated preview
    within(".markup-preview") do
      assert page.has_selector?("h3", text: "New Section")
      assert page.has_text?("Added during editing.")
    end
    
    # Save changes
    click_button "Update Contract"
    
    # Should show success message
    assert page.has_text?("Mortgage Contract updated successfully")
  end
  
  test "admin can publish and activate mortgage contracts" do
    sign_in_admin
    visit admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Should show draft status
    assert page.has_text?("Draft")
    
    # Should have publish button
    assert page.has_button?("Publish Contract")
    
    # Publish the contract
    accept_confirm "Are you sure you want to publish this contract? Published contracts cannot be directly edited." do
      click_button "Publish Contract"
    end
    
    # Should show success and updated status
    assert page.has_text?("Mortgage Contract published successfully")
    assert page.has_text?("Published")
    
    # Should now have activate button
    assert page.has_button?("Activate Contract")
    
    # Activate the contract
    accept_confirm "Are you sure you want to activate this version? This will deactivate the current active version." do
      click_button "Activate Contract"
    end
    
    # Should show success and active status
    assert page.has_text?("Mortgage Contract activated successfully")
    assert page.has_text?("Active")
  end
  
  test "admin can create new version when editing published contract" do
    # First publish the existing contract
    @existing_contract.update!(is_draft: false)
    
    sign_in_admin
    visit admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Should show published status
    assert page.has_text?("Published")
    
    # Click edit (new version)
    click_link "Edit (New Version)"
    
    # Should show new version creation notice
    assert page.has_text?("Create New Version")
    assert page.has_text?("Editing Published Contract")
    assert page.has_text?("editing will create a new draft version")
    
    # Modify content
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    content_textarea.send_keys("\n\n## Updated Section\n\nThis is version 2 content.")
    
    # Save as new version
    click_button "Create New Version"
    
    # Should create new draft version
    assert page.has_text?("New draft version created successfully")
    
    # Verify new version was created
    new_version = @mortgage.mortgage_contracts.order(:version).last
    assert new_version.content.include?("Updated Section")
    assert new_version.draft?
    assert_equal @existing_contract.version + 1, new_version.version
  end
  
  test "admin can use full page preview functionality" do
    sign_in_admin
    visit edit_admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Fill in some content
    fill_in "Title", with: "Preview Test Contract"
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    content_textarea.set("## Test Contract\n\nThis is for preview testing.\n\n**Important:** This is a test.")
    
    # Click preview button (opens new window)
    new_window = window_opened_by do
      click_button "Preview Contract"
    end
    
    # Switch to preview window
    within_window new_window do
      assert page.has_text?("Preview Test Contract")
      assert page.has_selector?("h2", text: "Test Contract")
      assert page.has_text?("This is for preview testing.")
      assert page.has_selector?("strong", text: "Important:")
    end
  end
  
  test "mortgage contracts index shows proper filtering and navigation" do
    # Create published and draft contracts
    published_contract = @mortgage.mortgage_contracts.create!(
      title: "Published Contract",
      content: "## Published\n\nThis is published.",
      is_draft: false,
      is_active: true,
      created_by: @admin
    )
    
    sign_in_admin
    visit admin_mortgage_mortgage_contracts_path(@mortgage)
    
    # Should see tabs for published and draft contracts
    assert page.has_link?("Published Contracts")
    assert page.has_link?("Draft Contracts")
    
    # Published tab should be active by default
    assert page.has_selector?(".tab-link.active", text: "Published Contracts")
    
    # Should show published contract
    assert page.has_text?(published_contract.title)
    assert page.has_text?("Active")
    
    # Click draft tab
    click_link "Draft Contracts"
    
    # Should show draft contract
    assert page.has_text?(@existing_contract.title)
    assert page.has_text?("Draft")
    
    # Should have action buttons
    assert page.has_link?("View")
    assert page.has_link?("Edit")
    assert page.has_link?("Publish")
    assert page.has_link?("Delete")
  end
  
  test "responsive design works on mobile viewport" do
    # Set mobile viewport
    page.driver.browser.manage.window.resize_to(375, 812)
    
    sign_in_admin
    visit edit_admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Should still show both form and preview sections
    assert page.has_selector?(".contract-editor-layout")
    assert page.has_selector?(".contract-form-column")
    assert page.has_selector?(".contract-preview-column")
    
    # Live preview should still work
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    content_textarea.send_keys("\n\n## Mobile Test\n\nTesting mobile layout.")
    
    sleep 0.5
    
    within(".markup-preview") do
      assert page.has_selector?("h2", text: "Mobile Test")
      assert page.has_text?("Testing mobile layout.")
    end
  end
  
  test "live preview handles special characters and edge cases" do
    sign_in_admin
    visit edit_admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Test special characters and markup edge cases
    content_textarea = find("textarea[name='mortgage_contract[content]']")
    content_textarea.set(
      "## Special Characters Test\n\n" +
      "Text with **bold** and regular text.\n\n" +
      "### Subsection\n\n" +
      "- Item with **embedded bold**\n" +
      "- Item with <script>alert('test')</script>\n" +
      "- Item with quotes \"and\" apostrophes\n\n" +
      "**Field:** Value with special chars & symbols\n" +
      "**Rate:** 4.5% per annum\n\n" +
      "Contact info:\n" +
      "Email: test@example.com\n" +
      "Phone: +1 (555) 123-4567"
    )
    
    sleep 0.5
    
    # Verify preview handles content safely
    within(".markup-preview") do
      # Should show formatted content
      assert page.has_selector?("h2", text: "Special Characters Test")
      assert page.has_selector?("h3", text: "Subsection")
      assert page.has_selector?("strong", text: "bold")
      assert page.has_selector?("strong", text: "embedded bold")
      
      # Should sanitize script tags
      assert_not page.has_selector?("script")
      assert page.has_text?("alert('test')")
      
      # Should handle quotes and special characters
      assert page.has_text?("quotes \"and\" apostrophes")
      assert page.has_text?("4.5% per annum")
      assert page.has_text?("+1 (555) 123-4567")
    end
  end
  
  test "navigation breadcrumbs and back buttons work correctly" do
    sign_in_admin
    visit edit_admin_mortgage_mortgage_contract_path(@mortgage, @existing_contract)
    
    # Should have back button
    assert page.has_link?("← Back to Contracts")
    
    # Click back button
    click_link "← Back to Contracts"
    
    # Should go to contracts index
    assert page.has_text?("Published Contracts")
    assert page.has_text?("Draft Contracts")
    
    # Should maintain mortgage context
    assert_current_path admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "error handling and validation work in browser" do
    sign_in_admin
    visit new_admin_mortgage_mortgage_contract_path(@mortgage)
    
    # Try to submit empty form
    click_button "Create Contract (Draft)"
    
    # Should show validation errors
    assert page.has_selector?(".alert-danger")
    assert page.has_text?("prohibited this Mortgage Contract from being saved")
    assert page.has_text?("can't be blank")
    
    # Form should still be visible with data
    assert page.has_field?("Title")
    assert page.has_field?("Contract Content")
  end
  
  private
  
  def sign_in_admin
    visit new_user_session_path
    fill_in "Email", with: @admin.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    
    # Wait for successful sign in
    assert page.has_text?("Dashboard")
  end
end