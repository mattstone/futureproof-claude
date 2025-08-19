require 'test_helper'

class MortgageContractPlaceholdersTest < ActionDispatch::IntegrationTest
  fixtures :none
  
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
  
  test "can create mortgage contract template with placeholders" do
    get new_admin_mortgage_mortgage_contract_path(@mortgage)
    assert_response :success
    
    contract_content = <<~CONTENT
      ## Agreement Parties
      
      **Customer:** {{primary_user_full_name}}
      **Address:** {{primary_user_address}}
      **Lender:** {{lender_name}}
      **Lender Address:** {{lender_address}}
      
      ## Terms
      
      This is a test agreement template.
    CONTENT
    
    assert_difference -> { MortgageContract.count }, 1 do
      post admin_mortgage_mortgage_contracts_path(@mortgage), params: {
        mortgage_contract: {
          title: "Test Template",
          content: contract_content
        }
      }
    end
    
    contract = MortgageContract.last
    assert_equal "Test Template", contract.title
    assert_includes contract.content, "{{primary_user_full_name}}"
    assert_includes contract.content, "{{lender_name}}"
    assert contract.draft?
  end
  
  test "placeholder substitution works correctly" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Test Template",
      content: "Customer: {{primary_user_full_name}} at {{primary_user_address}}\nLender: {{lender_name}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    # Test with sample data (no real associations)
    preview_content = contract.rendered_preview_content
    assert_includes preview_content, "John Smith"
    assert_includes preview_content, "123 Main Street"
    assert_includes preview_content, "Futureproof Financial Group"
    
    # Test with real associations
    rendered_content = contract.rendered_content
    assert_includes rendered_content, "John Smith" # from primary_user
    assert_includes rendered_content, "123 Main Street" # from primary_user address
    assert_includes rendered_content, "Futureproof Financial Group" # from mortgage lenders
  end
  
  test "can view contract with placeholder substitution" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "View Test Template",
      content: "Agreement between {{primary_user_full_name}} and {{lender_name}}",
      is_draft: false,
      created_by: @admin,
      primary_user: @customer
    )
    
    get admin_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_response :success
    
    # Should show substituted content
    assert_includes @response.body, "John Smith"
    assert_includes @response.body, "Futureproof Financial Group"
  end
  
  test "can update contract template" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Original Template",
      content: "Original: {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin
    )
    
    patch admin_mortgage_mortgage_contract_path(@mortgage, contract), params: {
      mortgage_contract: {
        title: "Updated Template",
        content: "Updated: {{primary_user_full_name}} and {{lender_name}}"
      }
    }
    
    contract.reload
    assert_equal "Updated Template", contract.title
    assert_includes contract.content, "{{lender_name}}"
  end
  
  test "contract workflow from template to active" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Workflow Template",
      content: "Customer: {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin
    )
    
    # Publish contract
    patch publish_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    contract.reload
    assert_not contract.draft?
    assert contract.published?
    
    # Activate contract
    patch activate_admin_mortgage_mortgage_contract_path(@mortgage, contract)
    contract.reload
    assert contract.is_active?
  end
  
  test "multiple users can be associated with contracts" do
    # Test primary user relationship
    contract = @mortgage.mortgage_contracts.create!(
      title: "Multi-User Template",
      content: "Primary: {{primary_user_full_name}}",
      is_draft: true,
      created_by: @admin,
      primary_user: @customer
    )
    
    assert_equal @customer, contract.primary_user
    
    # Test additional users through join table
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
    
    contract.additional_users << other_user
    assert_includes contract.additional_users, other_user
  end
  
  test "placeholder substitution handles missing data gracefully" do
    contract = @mortgage.mortgage_contracts.create!(
      title: "Missing Data Template",
      content: "Customer: {{primary_user_full_name}}\nAddress: {{primary_user_address}}", 
      is_draft: true,
      created_by: @admin
      # No primary_user set
    )
    
    # Should not crash when primary_user is nil
    rendered = contract.rendered_content
    assert_includes rendered, "{{primary_user_full_name}}" # Placeholder remains
    assert_includes rendered, "{{primary_user_address}}"
  end
  
  test "preview endpoint shows placeholder substitution" do
    post preview_admin_mortgage_mortgage_contracts_path(@mortgage), params: {
      mortgage_contract: {
        title: "Preview Test",
        content: "Customer: {{primary_user_full_name}}\nLender: {{lender_name}}"
      }
    }
    
    assert_response :success
    
    # Should show sample substitutions for preview
    assert_includes @response.body, "John Smith"
    assert_includes @response.body, "Futureproof Financial Group"
  end
  
  test "default contract template includes placeholders" do
    # Test that the default template creation includes our placeholders
    default_contract = MortgageContract.create_default
    
    assert_includes default_contract.content, "{{primary_user_full_name}}"
    assert_includes default_contract.content, "{{primary_user_address}}"
    assert_includes default_contract.content, "{{lender_name}}"
    assert_includes default_contract.content, "{{lender_address}}"
    assert_includes default_contract.content, "Agreement Parties"
    assert_includes default_contract.content, "Agreement Execution"
  end
end