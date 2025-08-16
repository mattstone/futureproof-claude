require "test_helper"

class Admin::EndToEndAdminTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_lender = lenders(:futureproof)
    @broker_lender = lenders(:broker)
    @futureproof_admin = users(:futureproof_admin)
    @broker_admin = users(:broker_admin)
    @wholesale_funder = wholesale_funders(:test_wholesale_funder)
    @regular_user = users(:user_one)
  end

  # Test complete admin navigation flow for futureproof admin
  test "futureproof admin can navigate through all admin pages" do
    sign_in @futureproof_admin
    
    # Dashboard
    get admin_dashboard_index_path
    assert_response :success
    assert_select "h1", /Dashboard|Back Office/
    
    # Applications
    get admin_applications_path
    assert_response :success
    assert_select "h1", /Applications/
    
    # Users  
    get admin_users_path
    assert_response :success
    assert_select "h1", /Users/
    
    # Contracts
    get admin_contracts_path
    assert_response :success
    assert_select "h1", /Contracts/
    
    # Lenders (futureproof-only)
    get admin_lenders_path
    assert_response :success
    assert_select "h1", /Lenders/
    
    # WholesaleFunders (futureproof-only)
    get admin_wholesale_funders_path  
    assert_response :success
    assert_select "h1", /WholesaleFunders/
    
    # Mortgages (futureproof-only)
    get admin_mortgages_path
    assert_response :success
    assert_select "h1", /Mortgages/
  end

  # Test lender admin restricted access
  test "lender admin has restricted navigation access" do
    sign_in @broker_admin
    
    # Allowed pages
    get admin_dashboard_index_path
    assert_response :success
    
    get admin_applications_path
    assert_response :success
    
    get admin_users_path
    assert_response :success
    
    get admin_contracts_path
    assert_response :success
    
    # Restricted pages
    get admin_lenders_path
    assert_redirected_to admin_dashboard_index_path
    
    get admin_wholesale_funders_path
    assert_redirected_to admin_dashboard_index_path
    
    get admin_mortgages_path
    assert_redirected_to admin_dashboard_index_path
  end

  # Test wholesale_funder show page functionality
  test "wholesale_funder show page displays correctly" do
    sign_in @futureproof_admin
    
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    
    # Check page content
    assert_select "h1", @wholesale_funder.name
    assert_select ".page-subtitle", /#{@wholesale_funder.country}/
    assert_select ".page-subtitle", /#{@wholesale_funder.currency}/
    
    # Check wholesale_funder details
    assert_select ".funder-name", @wholesale_funder.name
    assert_select ".currency-badge", /#{@wholesale_funder.currency}/
    
    # Check action buttons
    assert_select "a[href='#{edit_admin_wholesale_funder_path(@wholesale_funder)}']", "Edit WholesaleFunder"
    assert_select "a[href='#{admin_wholesale_funders_path}']", "Back to WholesaleFunders"
  end

  # Test lender show page functionality
  test "lender show page displays correctly" do
    sign_in @futureproof_admin
    
    get admin_lender_path(@futureproof_lender)
    assert_response :success
    
    # Check page content
    assert_select "h1", @futureproof_lender.name
    assert_select ".lender-type", /#{@futureproof_lender.lender_type.humanize}/
    
    # Check lender details
    assert_select ".detail-value", @futureproof_lender.name
    assert_select ".detail-value", @futureproof_lender.country
    assert_select "a[href='mailto:#{@futureproof_lender.contact_email}']"
    
    # Check action buttons
    assert_select "a[href='#{edit_admin_lender_path(@futureproof_lender)}']", "Edit Lender"
    assert_select "a[href='#{admin_lenders_path}']", "Back to Lenders"
  end

  # Test new wholesale_funder form
  test "new wholesale_funder form works correctly" do
    sign_in @futureproof_admin
    
    get new_admin_wholesale_funder_path
    assert_response :success
    
    # Check form is present
    assert_select "h1", "New WholesaleFunder"
    assert_select "form[action='#{admin_wholesale_funders_path}']"
    assert_select "input[name='wholesale_funder[name]']"
    assert_select "input[name='wholesale_funder[country]']"
    assert_select "select[name='wholesale_funder[currency]']"
    
    # Test form submission
    assert_difference('WholesaleFunder.count') do
      post admin_wholesale_funders_path, params: {
        wholesale_funder: {
          name: "Test E2E WholesaleFunder",
          country: "Canada",
          currency: "USD"
        }
      }
    end
    
    new_funder = WholesaleFunder.last
    assert_redirected_to admin_wholesale_funder_path(new_funder)
    assert_equal "Test E2E WholesaleFunder", new_funder.name
    assert_equal "Canada", new_funder.country
    assert_equal "USD", new_funder.currency
    
    # Clean up
    new_funder.destroy
  end

  # Test edit wholesale_funder form
  test "edit wholesale_funder form works correctly" do
    sign_in @futureproof_admin
    
    get edit_admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    
    # Check form is present with current values
    assert_select "h1", "Edit WholesaleFunder"
    assert_select "form[action='#{admin_wholesale_funder_path(@wholesale_funder)}']"
    assert_select "input[name='wholesale_funder[name]'][value='#{@wholesale_funder.name}']"
    
    # Test form submission
    patch admin_wholesale_funder_path(@wholesale_funder), params: {
      wholesale_funder: {
        name: "Updated E2E Test Name"
      }
    }
    
    assert_redirected_to admin_wholesale_funder_path(@wholesale_funder)
    @wholesale_funder.reload
    assert_equal "Updated E2E Test Name", @wholesale_funder.name
    
    # Restore original name
    @wholesale_funder.update!(name: "Test WholesaleFunder")
  end

  # Test wholesale_funder deletion
  test "wholesale_funder deletion works correctly" do
    sign_in @futureproof_admin
    
    # Create a test funder to delete
    test_funder = WholesaleFunder.create!(
      name: "To Be Deleted",
      country: "Test Country",
      currency: "AUD"
    )
    
    assert_difference('WholesaleFunder.count', -1) do
      delete admin_wholesale_funder_path(test_funder)
    end
    
    assert_redirected_to admin_wholesale_funders_path
    assert_match /successfully deleted/, flash[:notice]
  end

  # Test new lender form
  test "new lender form works correctly" do
    sign_in @futureproof_admin
    
    get new_admin_lender_path
    assert_response :success
    
    # Check form is present
    assert_select "h1", "New Lender"
    assert_select "form[action='#{admin_lenders_path}']"
    assert_select "input[name='lender[name]']"
    assert_select "input[name='lender[contact_email]']"
    
    # Test form submission
    assert_difference('Lender.count') do
      post admin_lenders_path, params: {
        lender: {
          name: "Test E2E Lender",
          lender_type: "lender",
          country: "Australia",
          contact_email: "test@e2elender.com"
        }
      }
    end
    
    new_lender = Lender.last
    assert_redirected_to admin_lender_path(new_lender)
    assert_equal "Test E2E Lender", new_lender.name
    assert_equal "lender", new_lender.lender_type
    
    # Clean up
    new_lender.destroy
  end

  # Test admin search functionality
  test "wholesale_funder search works correctly" do
    sign_in @futureproof_admin
    
    # Test search
    post search_admin_wholesale_funders_path, params: { search: "Test" }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  # Test error handling
  test "handles wholesale_funder creation errors correctly" do
    sign_in @futureproof_admin
    
    # Try to create with invalid data
    post admin_wholesale_funders_path, params: {
      wholesale_funder: {
        name: "", # Invalid - blank name
        country: "Australia",
        currency: "AUD"
      }
    }
    
    assert_response :unprocessable_entity
    assert_select ".form-errors", /prohibited this wholesale_funder from being saved/
  end

  # Test navigation menu visibility
  test "navigation menu shows correct links based on admin type" do
    # Test futureproof admin
    sign_in @futureproof_admin
    get admin_dashboard_index_path
    assert_response :success
    
    # Should see all links
    assert_select "a[href='#{admin_lenders_path}']", "Lenders"
    assert_select "a[href='#{admin_wholesale_funders_path}']", "WholesaleFunders"
    
    # Test lender admin
    sign_in @broker_admin
    get admin_dashboard_index_path
    assert_response :success
    
    # Should NOT see restricted links
    assert_select "a[href='#{admin_lenders_path}']", count: 0
    assert_select "a[href='#{admin_wholesale_funders_path}']", count: 0
  end

  # Test model methods are working in views
  test "model methods work correctly in views" do
    sign_in @futureproof_admin
    
    # Test wholesale_funder methods
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    
    # Check that currency symbol is displayed
    assert_match @wholesale_funder.currency_symbol, response.body
    
    # Check that formatted amounts are displayed
    if @wholesale_funder.total_capital > 0
      assert_match @wholesale_funder.formatted_total_capital, response.body
    end
    
    # Test lender methods
    get admin_lender_path(@futureproof_lender)
    assert_response :success
    
    # Check that lender type is displayed correctly
    assert_match @futureproof_lender.lender_type.humanize, response.body
  end

  # Test that all essential routes exist and work
  test "all essential admin routes exist and respond" do
    sign_in @futureproof_admin
    
    routes_to_test = [
      admin_dashboard_index_path,
      admin_lenders_path,
      admin_wholesale_funders_path,
      admin_lender_path(@futureproof_lender),
      admin_wholesale_funder_path(@wholesale_funder),
      new_admin_lender_path,
      new_admin_wholesale_funder_path,
      edit_admin_lender_path(@futureproof_lender),
      edit_admin_wholesale_funder_path(@wholesale_funder)
    ]
    
    routes_to_test.each do |route|
      get route
      assert_response :success, "Route #{route} should be accessible"
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password"
      }
    }
    follow_redirect! if response.status == 302
  end
end