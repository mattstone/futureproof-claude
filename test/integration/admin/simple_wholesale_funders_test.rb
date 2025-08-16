require "test_helper"

class Admin::SimpleWholesaleFundersTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    DatabaseCleaner.start
    
    # Create lender
    @futureproof_lender = Lender.create!(
      name: "Futureproof",
      lender_type: :futureproof,
      address: "Test Address", 
      postcode: "2000",
      country: "Australia",
      contact_email: "admin@futureproof.com",
      contact_telephone: "0432212713"
    )
    
    # Create admin user
    @admin_user = User.create!(
      email: "admin@futureproof.com",
      password: "password",
      first_name: "Admin",
      last_name: "User",
      admin: true,
      confirmed_at: 1.week.ago,
      terms_accepted: true,
      lender: @futureproof_lender
    )
    
    # Create wholesale funder
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    # Create funder pool
    @funder_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Test Pool",
      amount: 1000000.00,
      allocated: 250000.00
    )
  end

  teardown do
    DatabaseCleaner.clean
  end

  test "wholesale funders index loads successfully for futureproof admin" do
    sign_in @admin_user
    get admin_wholesale_funders_path
    assert_response :success
    assert_select 'h1', /Wholesale Funders/i
    assert_select 'td', @wholesale_funder.name
  end

  test "wholesale funder show page loads successfully" do
    sign_in @admin_user
    get admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
    assert_select 'h1', @wholesale_funder.name
  end

  test "wholesale funder edit page loads successfully" do
    sign_in @admin_user
    get edit_admin_wholesale_funder_path(@wholesale_funder)
    assert_response :success
  end

  test "wholesale funder new page loads successfully" do
    sign_in @admin_user
    get new_admin_wholesale_funder_path
    assert_response :success
  end

  test "nested funder pool routes work correctly" do
    sign_in @admin_user
    
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
    sign_in @admin_user
    post search_admin_wholesale_funders_path, params: { search: @wholesale_funder.name }
    assert_response :success
  end

  test "wholesale funder associations work correctly" do
    # Ensure the wholesale funder has funder pools association
    assert_respond_to @wholesale_funder, :funder_pools
    
    # Test that the association returns the correct type
    assert_kind_of FunderPool, @wholesale_funder.funder_pools.first
    assert_equal @funder_pool, @wholesale_funder.funder_pools.first
  end

  test "wholesale funder model methods work" do
    # Test that wholesale funder has required methods
    assert_respond_to @wholesale_funder, :display_name
    assert_respond_to @wholesale_funder, :pools_count
    assert_respond_to @wholesale_funder, :total_capital
    assert_respond_to @wholesale_funder, :total_allocated
    assert_respond_to @wholesale_funder, :formatted_total_capital
    
    # Test actual values
    assert_equal 1, @wholesale_funder.pools_count
    assert_equal 1000000.00, @wholesale_funder.total_capital
    assert_equal 250000.00, @wholesale_funder.total_allocated
  end

  test "funder pool belongs to wholesale funder" do
    # Test that funder pool has correct association
    assert_respond_to @funder_pool, :wholesale_funder
    assert_kind_of WholesaleFunder, @funder_pool.wholesale_funder
    assert_equal @wholesale_funder, @funder_pool.wholesale_funder
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