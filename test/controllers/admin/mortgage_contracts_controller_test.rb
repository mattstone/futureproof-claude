require 'test_helper'

class Admin::MortgageContractsControllerTest < ActionDispatch::IntegrationTest
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
  
  test "index renders correctly with nested route" do
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :success
    
    assert_select ".contract-tabs"
    assert_select ".tab-link", text: "Published Contracts"
    assert_select ".tab-link", text: "Draft Contracts"
    assert_select "a[href='#{new_admin_mortgage_mortgage_contract_path(@mortgage)}']", text: "Create New Contract"
  end
  
  test "show renders correctly with nested route" do
    get admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    assert_select "h2", text: @mortgage_contract.title
    assert_select ".contract-preview"
    assert_select "a[href='#{admin_mortgage_mortgage_contracts_path(@mortgage)}']", text: "← Back to Contracts"
  end
  
  test "new renders correctly with nested route" do
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :success
    
    assert_select "h2", text: "Create New Mortgage Contract"
    assert_select ".contract-editor-layout"
    assert_select ".markup-preview"
    assert_select "form[action='#{admin_mortgage_mortgage_contracts_path(@mortgage)}']"
  end
  
  test "edit renders correctly with nested route" do
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :success
    
    assert_select "h2", text: "Edit Contract"
    assert_select ".contract-editor-layout"
    assert_select ".markup-preview"
    assert_select "form[action='#{admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)}']"
  end
  
  test "create works with nested route and proper associations" do
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
    assert_equal @admin, new_contract.created_by
    assert new_contract.draft?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract created successfully/
  end
  
  test "update works with nested route" do
    patch admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract), params: {
      mortgage_contract: {
        title: "Updated Contract",
        content: "## Updated\n\nUpdated content."
      }
    }
    
    @mortgage_contract.reload
    assert_equal "Updated Contract", @mortgage_contract.title
    assert @mortgage_contract.content.include?("Updated content")
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
  end
  
  test "publish action works correctly" do
    assert @mortgage_contract.draft?
    
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    
    @mortgage_contract.reload
    assert_not @mortgage_contract.draft?
    assert_not @mortgage_contract.is_active?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract published successfully/
  end
  
  test "activate action works correctly" do
    @mortgage_contract.update!(is_draft: false)
    
    patch activate_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    
    @mortgage_contract.reload
    assert_not @mortgage_contract.draft?
    assert @mortgage_contract.is_active?
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract activated successfully/
  end
  
  test "destroy action works for draft contracts" do
    assert_difference -> { MortgageContract.count }, -1 do
      delete admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    end
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
    follow_redirect!
    assert_select ".alert-success", text: /Mortgage Contract deleted successfully/
  end
  
  test "preview action renders contract HTML" do
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Preview Contract",
        content: "## Preview Test\n\n**Bold text** and regular text.\n\n- List item 1\n- List item 2"
      }
    }
    
    assert_response :success
    assert_select "section.legal-section"
    assert_select "h2", text: "Preview Test"
    assert_select "strong", text: "Bold text"
    assert_select "ul"
    assert_select "li", text: "List item 1"
  end
  
  test "creating new version for published contract" do
    # Publish the contract first
    @mortgage_contract.update!(is_draft: false)
    
    # Try to update it (should create new version)
    assert_difference -> { MortgageContract.count }, 1 do
      patch admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract), params: {
        mortgage_contract: {
          title: "Version 2",
          content: "## Version 2\n\nNew version content."
        }
      }
    end
    
    new_version = MortgageContract.order(:version).last
    assert_equal @mortgage_contract.version + 1, new_version.version
    assert_equal @mortgage, new_version.mortgage
    assert new_version.draft?
    assert_equal "Version 2", new_version.title
    
    # Original should remain unchanged
    @mortgage_contract.reload
    assert_not @mortgage_contract.draft?
    assert_equal "Test Contract", @mortgage_contract.title
    
    assert_redirected_to admin_mortgage_mortgage_contracts_path(@mortgage)
    follow_redirect!
    assert_select ".alert-success", text: /New draft version created successfully/
  end
  
  test "access control enforces futureproof admin requirement" do
    # Create external admin
    external_lender = Lender.create!(
      name: "External Lender",
      contact_email: "external@example.com",
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
    
    sign_out @admin
    sign_in external_admin
    
    # All actions should be forbidden
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :redirect
    
    get admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :redirect
    
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :redirect
    
    get edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)
    assert_response :redirect
    
    post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: { title: "Blocked", content: "Should not work" }
    }
    assert_response :redirect
  end
  
  test "contract scoping ensures contracts belong to specified mortgage" do
    # Create another mortgage with its own contract
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
    
    # Try to access other contract through wrong mortgage route
    assert_raises(ActiveRecord::RecordNotFound) do
      get admin_mortgage_mortgage_contract_path(@mortgage, other_contract)
    end
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_admin_mortgage_mortgage_contract_path(@mortgage, other_contract)
    end
    
    assert_raises(ActiveRecord::RecordNotFound) do
      patch admin_mortgage_mortgage_contract_path(@mortgage, other_contract), params: {
        mortgage_contract: { title: "Hacked" }
      }
    end
  end
  
  test "index action properly scopes contracts to mortgage" do
    # Create contracts for different mortgages
    other_mortgage = Mortgage.create!(
      name: "Other Mortgage",
      mortgage_type: :principal_and_interest,
      lvr: 75.0
    )
    
    other_contract = other_mortgage.mortgage_contracts.create!(
      title: "Other Contract",
      content: "## Other\n\nShould not appear.",
      is_draft: true,
      created_by: @admin
    )
    
    get admin_mortgage_mortgage_contracts_path(@mortgage)
    assert_response :success
    
    # Should only show contracts for the specified mortgage
    assert_select "#drafts-tab", text: @mortgage_contract.title
    assert_select "#drafts-tab", { text: other_contract.title, count: 0 }
  end
  
  test "error handling for invalid parameters" do
    # Try to create contract with invalid data
    post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "", # Required field
        content: "" # Required field
      }
    }
    
    assert_response :unprocessable_entity
    assert_select ".alert-danger"
    assert_select "li", text: /can't be blank/
  end
  
  test "routes are properly nested and accessible" do
    # Test all the nested routes work
    routes_to_test = [
      [:get, admin_mortgage_mortgage_contracts_path(@mortgage)],
      [:get, new_admin_mortgage_mortgage_contract_path(@mortgage)],
      [:get, admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)],
      [:get, edit_admin_mortgage_mortgage_contract_path(@mortgage, @mortgage_contract)]
    ]
    
    routes_to_test.each do |method, path|
      send(method, path)
      assert_response :success, "Failed for #{method.upcase} #{path}"
    end
  end
  
  test "current_user is properly set for change tracking" do
    post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Tracked Contract",
        content: "## Tracked\n\nThis should be tracked."
      }
    }
    
    new_contract = MortgageContract.last
    assert_equal @admin, new_contract.created_by
    
    # Check that audit versions are created
    assert new_contract.mortgage_contract_versions.any?
    version = new_contract.mortgage_contract_versions.first
    assert_equal @admin, version.user
    assert_equal 'created', version.action
  end
  
  test "preview action handles empty content gracefully" do
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Empty Contract",
        content: ""
      }
    }
    
    assert_response :success
    # Should render without errors even with empty content
  end
end