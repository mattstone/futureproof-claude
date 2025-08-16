require "test_helper"

class Admin::WholesaleFundersTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_admin = users(:admin_user)
    @wholesale_funder = wholesale_funders(:one)
    @funder_pool = funder_pools(:one)
  end

  test "wholesale funders index loads successfully for futureproof admin" do
    sign_in @futureproof_admin
    get admin_wholesale_funders_path
    assert_response :success
    assert_select 'h1', /Wholesale Funders/i
  end

  test "wholesale funder show page loads successfully" do
    sign_in @futureproof_admin
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    assert_select 'h1', @wholesale_funder.name
  end

  test "wholesale funder edit page loads successfully" do
    sign_in @futureproof_admin
    get edit_admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
  end

  test "wholesale funder new page loads successfully" do
    sign_in @futureproof_admin
    get new_admin_wholesale_funder_path
    assert_response :success
  end

  test "nested funder pool routes work correctly" do
    sign_in @futureproof_admin
    
    # Test new funder pool path
    get new_admin_wholesale_funder_funder_pool_path(@wholesale_funder)
    assert_response :success
    
    # Test funder pool show path
    get admin_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool)
    assert_response :success
    
    # Test funder pool edit path
    get edit_admin_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool)
    assert_response :success
  end

  test "search functionality works" do
    sign_in @futureproof_admin
    post search_admin_wholesale_funders_path, params: { search: @wholesale_funder.name }
    assert_response :success
  end

  test "wholesale funder associations work correctly" do
    sign_in @futureproof_admin
    
    # Ensure the wholesale funder has funder pools association
    assert_respond_to @wholesale_funder, :funder_pools
    
    # Test that the association returns the correct type
    if @wholesale_funder.funder_pools.any?
      assert_kind_of FunderPool, @wholesale_funder.funder_pools.first
    end
  end

  test "wholesale funder model methods work" do
    # Test that wholesale funder has required methods
    assert_respond_to @wholesale_funder, :display_name
    assert_respond_to @wholesale_funder, :pools_count
    assert_respond_to @wholesale_funder, :total_capital
    assert_respond_to @wholesale_funder, :total_allocated
    assert_respond_to @wholesale_funder, :formatted_total_capital
  end

  test "funder pool belongs to wholesale funder" do
    # Test that funder pool has correct association
    assert_respond_to @funder_pool, :wholesale_funder
    assert_kind_of WholesaleFunder, @funder_pool.wholesale_funder
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
  end
end