require "test_helper"

class Admin::LendersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    sign_in @admin_user
    @lender = lenders(:broker_lender)
    @master_lender = lenders(:futureproof_financial)
  end

  # === Index Tests ===

  test "should get index" do
    get admin_lenders_url
    assert_response :success
    assert_select "h1", "Lenders"
    assert_select "a", "New Lender"
    assert_select "table tbody tr", count: Lender.count
  end

  test "should show lenders with correct badges" do
    get admin_lenders_url
    assert_response :success
    
    # Check for master badge
    assert_select ".master-badge", "MASTER"
    
    # Check for lender type badges
    assert_select ".lender-type-master"
    assert_select ".lender-type-broker"
  end

  test "should show contact information" do
    get admin_lenders_url
    assert_response :success
    
    # Check email links are present
    assert_select "a[href^='mailto:']"
    
    # Check phone numbers are displayed
    assert_select ".contact-phone"
  end

  # === Show Tests ===

  test "should show lender" do
    get admin_lender_url(@lender)
    assert_response :success
    assert_select "h3", @lender.name
    assert_select ".detail-value", text: /#{@lender.country}/
    assert_select ".detail-value a[href*='mailto:']", text: @lender.contact_email
  end

  test "should show master lender with special badge" do
    get admin_lender_url(@master_lender)
    assert_response :success
    assert_select ".master-badge", "MASTER LENDER"
    assert_select ".lender-type-master"
  end

  test "should show edit and delete buttons for broker" do
    get admin_lender_url(@lender)
    assert_response :success
    assert_select "a", "Edit Lender"
    assert_select "a", "Delete"
  end

  test "should not show delete button for master lender" do
    get admin_lender_url(@master_lender)
    assert_response :success
    assert_select "a", "Edit Lender"
    assert_select "a", text: "Delete", count: 0
  end

  # === New Tests ===

  test "should get new" do
    get new_admin_lender_url
    assert_response :success
    assert_select "h1", "New Lender"
    assert_select "form"
    assert_select "select#lender_lender_type"
    assert_select "input#lender_name"
    assert_select "input#lender_contact_email"
  end

  test "should show all form fields" do
    get new_admin_lender_url
    assert_response :success
    
    # Check all required fields are present
    assert_select "input#lender_name"
    assert_select "select#lender_lender_type"
    assert_select "input#lender_country"
    assert_select "input#lender_contact_email"
    assert_select "textarea#lender_address"
    assert_select "input#lender_postcode"
    assert_select "select#lender_contact_telephone_country_code"
    assert_select "input#lender_contact_telephone"
  end

  # === Create Tests ===

  test "should create broker lender" do
    assert_difference("Lender.count") do
      post admin_lenders_url, params: { 
        lender: { 
          lender_type: "broker",
          name: "New Test Lender",
          country: "Australia",
          contact_email: "test@newlender.com",
          address: "123 New Street",
          postcode: "4000",
          contact_telephone: "0412345678",
          contact_telephone_country_code: "+61"
        } 
      }
    end

    lender = Lender.last
    assert_redirected_to admin_lender_url(lender)
    assert_equal "New Test Lender", lender.name
    assert_equal "broker", lender.lender_type
    assert_equal "test@newlender.com", lender.contact_email
  end

  test "should not create lender with invalid data" do
    assert_no_difference("Lender.count") do
      post admin_lenders_url, params: { 
        lender: { 
          lender_type: "broker",
          name: "", # Missing required field
          country: "Australia",
          contact_email: "invalid-email" # Invalid email
        } 
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "should not create second master lender" do
    assert_no_difference("Lender.count") do
      post admin_lenders_url, params: { 
        lender: { 
          lender_type: "master",
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

  test "should get edit for broker lender" do
    get edit_admin_lender_url(@lender)
    assert_response :success
    assert_select "h1", "Edit Lender"
    assert_select "form"
    assert_select "input[value='#{@lender.name}']"
  end

  test "should get edit for master lender" do
    get edit_admin_lender_url(@master_lender)
    assert_response :success
    assert_select "h1", "Edit Lender"
    assert_select ".field-note", text: /Only one master lender is allowed/
  end

  # === Update Tests ===

  test "should update broker lender" do
    patch admin_lender_url(@lender), params: { 
      lender: { 
        name: "Updated Lender Name",
        address: "Updated Address",
        contact_telephone: "0987654321"
      } 
    }

    assert_redirected_to admin_lender_url(@lender)
    @lender.reload
    assert_equal "Updated Lender Name", @lender.name
    assert_equal "Updated Address", @lender.address
    assert_equal "0987654321", @lender.contact_telephone
  end

  test "should update master lender" do
    patch admin_lender_url(@master_lender), params: { 
      lender: { 
        address: "Updated Master Address",
        contact_telephone: "0123456789"
      } 
    }

    assert_redirected_to admin_lender_url(@master_lender)
    @master_lender.reload
    assert_equal "Updated Master Address", @master_lender.address
    assert_equal "0123456789", @master_lender.contact_telephone
  end

  test "should not update lender with invalid data" do
    patch admin_lender_url(@lender), params: { 
      lender: { 
        name: "", # Invalid
        contact_email: "invalid-email" # Invalid
      } 
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    
    # Ensure data wasn't changed
    @lender.reload
    assert_not_equal "", @lender.name
  end

  test "should not allow changing broker to master when master exists" do
    patch admin_lender_url(@lender), params: { 
      lender: { 
        lender_type: "master"
      } 
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors"
    
    @lender.reload
    assert_equal "broker", @lender.lender_type
  end

  # === Destroy Tests ===

  test "should destroy broker lender" do
    assert_difference("Lender.count", -1) do
      delete admin_lender_url(@lender)
    end

    assert_redirected_to admin_lenders_url
    assert_nil Lender.find_by(id: @lender.id)
  end

  test "should not destroy master lender" do
    assert_no_difference("Lender.count") do
      delete admin_lender_url(@master_lender)
    end

    assert_redirected_to admin_lenders_url
    assert_not_nil Lender.find(@master_lender.id)
  end

  # === Authorization Tests ===

  test "should require admin authentication" do
    sign_out @admin_user
    
    get admin_lenders_url
    assert_redirected_to new_user_session_url
  end

  test "should not allow regular user access" do
    regular_user = users(:john)
    sign_out @admin_user
    sign_in regular_user
    
    get admin_lenders_url
    assert_redirected_to root_url
  end

  # === Search and Filter Tests ===

  test "should handle search parameter" do
    get admin_lenders_url(search: "Futureproof")
    assert_response :success
    # The controller doesn't implement search yet, but should handle the parameter
  end

  # === Flash Message Tests ===

  test "should show success notice after creation" do
    post admin_lenders_url, params: { 
      lender: { 
        lender_type: "broker",
        name: "Flash Test Lender",
        country: "Australia",
        contact_email: "flash@test.com"
      } 
    }

    follow_redirect!
    assert_select ".alert-success", text: /Lender was successfully created/
  end

  test "should show success notice after update" do
    patch admin_lender_url(@lender), params: { 
      lender: { name: "Updated for Flash Test" } 
    }

    follow_redirect!
    assert_select ".alert-success", text: /Lender was successfully updated/
  end

  test "should show success notice after deletion" do
    delete admin_lender_url(@lender)

    follow_redirect!
    assert_select ".alert-success", text: /Lender was successfully deleted/
  end

  test "should show error alert when trying to delete master" do
    delete admin_lender_url(@master_lender)

    follow_redirect!
    assert_select ".alert-danger", text: /Master lender cannot be deleted/
  end
end
