require "test_helper"

class Admin::FundersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    sign_in @admin_user
    @funder = funders(:test_wholesale_fund)
  end

  test "should get index" do
    get admin_funders_url
    assert_response :success
    assert_select "h1", "Funders"
    assert_select "a", "New Funder"
  end

  test "should get index with search" do
    get admin_funders_url(search: "Test")
    assert_response :success
    assert_select "table tbody tr", count: 1
  end

  test "should get index with country filter" do
    get admin_funders_url(country: "Australia")
    assert_response :success
  end

  test "should get index with currency filter" do
    get admin_funders_url(currency: "AUD")
    assert_response :success
  end

  test "should show funder" do
    get admin_funder_url(@funder)
    assert_response :success
    assert_select "h1", @funder.name
    assert_select ".detail-value", text: @funder.country
  end

  test "should get new" do
    get new_admin_funder_url
    assert_response :success
    assert_select "h1", "New Funder"
    assert_select "form"
  end

  test "should create funder" do
    assert_difference("Funder.count") do
      post admin_funders_url, params: { 
        funder: { 
          name: "New Test Funder", 
          country: "Canada", 
          currency: "USD" 
        } 
      }
    end

    assert_redirected_to admin_funder_url(Funder.last)
    follow_redirect!
    assert_select "h1", "New Test Funder"
  end

  test "should not create funder with invalid params" do
    assert_no_difference("Funder.count") do
      post admin_funders_url, params: { 
        funder: { 
          name: "", 
          country: "", 
          currency: "INVALID" 
        } 
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "should get edit" do
    get edit_admin_funder_url(@funder)
    assert_response :success
    assert_select "h1", "Edit Funder"
    assert_select "form"
  end

  test "should update funder" do
    patch admin_funder_url(@funder), params: { 
      funder: { 
        name: "Updated Funder Name",
        country: "New Zealand",
        currency: "USD"
      } 
    }
    
    assert_redirected_to admin_funder_url(@funder)
    @funder.reload
    assert_equal "Updated Funder Name", @funder.name
    assert_equal "New Zealand", @funder.country
    assert_equal "USD", @funder.currency
  end

  test "should not update funder with invalid params" do
    patch admin_funder_url(@funder), params: { 
      funder: { 
        name: "", 
        currency: "INVALID" 
      } 
    }
    
    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "should destroy funder" do
    assert_difference("Funder.count", -1) do
      delete admin_funder_url(@funder)
    end

    assert_redirected_to admin_funders_url
    follow_redirect!
    assert_select ".alert-success", /successfully deleted/i
  end

  test "should require authentication" do
    delete destroy_user_session_path
    
    get admin_funders_url
    assert_redirected_to new_user_session_url
  end

  test "should show empty state when no funders" do
    Funder.destroy_all
    
    get admin_funders_url
    assert_response :success
    assert_select ".empty-state h3", "No funders found"
    assert_select ".empty-state a", "Create New Funder"
  end

  test "should show filtered empty state" do
    get admin_funders_url(search: "nonexistent")
    assert_response :success
    assert_select ".empty-state", /No funders match your current filters/
  end

  test "should handle search action with turbo stream" do
    post search_admin_funders_url, params: { search: "Test" }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
  end

  test "should handle search action with HTML redirect" do
    post search_admin_funders_url, params: { search: "Test", country: "Australia" }
    assert_redirected_to admin_funders_url(search: "Test", country: "Australia")
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password123'
      }
    }
  end
end
