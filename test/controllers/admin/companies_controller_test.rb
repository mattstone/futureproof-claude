require "test_helper"

class Admin::CompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    sign_in @admin_user
    @company = companies(:broker_company)
    @master_company = companies(:futureproof_financial)
  end

  # === Index Tests ===

  test "should get index" do
    get admin_companies_url
    assert_response :success
    assert_select "h1", "Companies"
    assert_select "a", "New Company"
    assert_select "table tbody tr", count: Company.count
  end

  test "should show companies with correct badges" do
    get admin_companies_url
    assert_response :success
    
    # Check for master badge
    assert_select ".master-badge", "MASTER"
    
    # Check for company type badges
    assert_select ".company-type-master"
    assert_select ".company-type-broker"
  end

  test "should show contact information" do
    get admin_companies_url
    assert_response :success
    
    # Check email links are present
    assert_select "a[href^='mailto:']"
    
    # Check phone numbers are displayed
    assert_select ".contact-phone"
  end

  # === Show Tests ===

  test "should show company" do
    get admin_company_url(@company)
    assert_response :success
    assert_select "h3", @company.name
    assert_select ".detail-value", text: /#{@company.country}/
    assert_select ".detail-value a[href*='mailto:']", text: @company.contact_email
  end

  test "should show master company with special badge" do
    get admin_company_url(@master_company)
    assert_response :success
    assert_select ".master-badge", "MASTER COMPANY"
    assert_select ".company-type-master"
  end

  test "should show edit and delete buttons for broker" do
    get admin_company_url(@company)
    assert_response :success
    assert_select "a", "Edit Company"
    assert_select "a", "Delete"
  end

  test "should not show delete button for master company" do
    get admin_company_url(@master_company)
    assert_response :success
    assert_select "a", "Edit Company"
    assert_select "a", text: "Delete", count: 0
  end

  # === New Tests ===

  test "should get new" do
    get new_admin_company_url
    assert_response :success
    assert_select "h1", "New Company"
    assert_select "form"
    assert_select "select#company_company_type"
    assert_select "input#company_name"
    assert_select "input#company_contact_email"
  end

  test "should show all form fields" do
    get new_admin_company_url
    assert_response :success
    
    # Check all required fields are present
    assert_select "input#company_name"
    assert_select "select#company_company_type"
    assert_select "input#company_country"
    assert_select "input#company_contact_email"
    assert_select "textarea#company_address"
    assert_select "input#company_postcode"
    assert_select "select#company_contact_telephone_country_code"
    assert_select "input#company_contact_telephone"
  end

  # === Create Tests ===

  test "should create broker company" do
    assert_difference("Company.count") do
      post admin_companies_url, params: { 
        company: { 
          company_type: "broker",
          name: "New Test Company",
          country: "Australia",
          contact_email: "test@newcompany.com",
          address: "123 New Street",
          postcode: "4000",
          contact_telephone: "0412345678",
          contact_telephone_country_code: "+61"
        } 
      }
    end

    company = Company.last
    assert_redirected_to admin_company_url(company)
    assert_equal "New Test Company", company.name
    assert_equal "broker", company.company_type
    assert_equal "test@newcompany.com", company.contact_email
  end

  test "should not create company with invalid data" do
    assert_no_difference("Company.count") do
      post admin_companies_url, params: { 
        company: { 
          company_type: "broker",
          name: "", # Missing required field
          country: "Australia",
          contact_email: "invalid-email" # Invalid email
        } 
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "should not create second master company" do
    assert_no_difference("Company.count") do
      post admin_companies_url, params: { 
        company: { 
          company_type: "master",
          name: "Second Master",
          country: "Australia",
          contact_email: "second@master.com"
        } 
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  # === Edit Tests ===

  test "should get edit for broker company" do
    get edit_admin_company_url(@company)
    assert_response :success
    assert_select "h1", "Edit Company"
    assert_select "form"
    assert_select "input[value='#{@company.name}']"
  end

  test "should get edit for master company" do
    get edit_admin_company_url(@master_company)
    assert_response :success
    assert_select "h1", "Edit Company"
    assert_select ".field-note", text: /Only one master company is allowed/
  end

  # === Update Tests ===

  test "should update broker company" do
    patch admin_company_url(@company), params: { 
      company: { 
        name: "Updated Company Name",
        address: "Updated Address",
        contact_telephone: "0987654321"
      } 
    }

    assert_redirected_to admin_company_url(@company)
    @company.reload
    assert_equal "Updated Company Name", @company.name
    assert_equal "Updated Address", @company.address
    assert_equal "0987654321", @company.contact_telephone
  end

  test "should update master company" do
    patch admin_company_url(@master_company), params: { 
      company: { 
        address: "Updated Master Address",
        contact_telephone: "0123456789"
      } 
    }

    assert_redirected_to admin_company_url(@master_company)
    @master_company.reload
    assert_equal "Updated Master Address", @master_company.address
    assert_equal "0123456789", @master_company.contact_telephone
  end

  test "should not update company with invalid data" do
    patch admin_company_url(@company), params: { 
      company: { 
        name: "", # Invalid
        contact_email: "invalid-email" # Invalid
      } 
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    
    # Ensure data wasn't changed
    @company.reload
    assert_not_equal "", @company.name
  end

  test "should not allow changing broker to master when master exists" do
    patch admin_company_url(@company), params: { 
      company: { 
        company_type: "master"
      } 
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    
    @company.reload
    assert_equal "broker", @company.company_type
  end

  # === Destroy Tests ===

  test "should destroy broker company" do
    assert_difference("Company.count", -1) do
      delete admin_company_url(@company)
    end

    assert_redirected_to admin_companies_url
    assert_nil Company.find_by(id: @company.id)
  end

  test "should not destroy master company" do
    assert_no_difference("Company.count") do
      delete admin_company_url(@master_company)
    end

    assert_redirected_to admin_companies_url
    assert_not_nil Company.find(@master_company.id)
  end

  # === Authorization Tests ===

  test "should require admin authentication" do
    sign_out @admin_user
    
    get admin_companies_url
    assert_redirected_to new_user_session_url
  end

  test "should not allow regular user access" do
    regular_user = users(:john)
    sign_out @admin_user
    sign_in regular_user
    
    get admin_companies_url
    assert_redirected_to root_url
  end

  # === Search and Filter Tests ===

  test "should handle search parameter" do
    get admin_companies_url(search: "Futureproof")
    assert_response :success
    # The controller doesn't implement search yet, but should handle the parameter
  end

  # === Flash Message Tests ===

  test "should show success notice after creation" do
    post admin_companies_url, params: { 
      company: { 
        company_type: "broker",
        name: "Flash Test Company",
        country: "Australia",
        contact_email: "flash@test.com"
      } 
    }

    follow_redirect!
    assert_select ".alert-success", text: /Company was successfully created/
  end

  test "should show success notice after update" do
    patch admin_company_url(@company), params: { 
      company: { name: "Updated for Flash Test" } 
    }

    follow_redirect!
    assert_select ".alert-success", text: /Company was successfully updated/
  end

  test "should show success notice after deletion" do
    delete admin_company_url(@company)

    follow_redirect!
    assert_select ".alert-success", text: /Company was successfully deleted/
  end

  test "should show error alert when trying to delete master" do
    delete admin_company_url(@master_company)

    follow_redirect!
    assert_select ".alert-danger", text: /Master company cannot be deleted/
  end
end
