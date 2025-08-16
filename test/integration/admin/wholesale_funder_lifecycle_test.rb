require "test_helper"

class Admin::WholesaleFunderLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    # Create a test admin user (assuming we need authentication)
    @admin_user = users(:one) rescue nil
    
    # Mock admin authentication if needed
    # sign_in @admin_user if respond_to?(:sign_in)
  end

  test "complete wholesale funder and funder pool lifecycle" do
    # Step 1: Create a new wholesale funder
    get "/admin/wholesale_funders/new"
    assert_response :success
    assert_select "form"
    assert_select "input[name='wholesale_funder[name]']"
    assert_select "input[name='wholesale_funder[country]']"
    assert_select "select[name='wholesale_funder[currency]']"

    post "/admin/wholesale_funders", params: {
      wholesale_funder: {
        name: "Test Lifecycle WF",
        country: "Australia", 
        currency: "AUD"
      }
    }
    assert_response :redirect
    
    # Follow the redirect to the wholesale funder show page
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Test Lifecycle WF"
    
    # Get the wholesale funder ID from the current path
    wholesale_funder_id = request.path.match(/\/admin\/wholesale_funders\/(\d+)/)[1]
    
    # Step 2: View the wholesale funder show page
    get "/admin/wholesale_funders/#{wholesale_funder_id}"
    assert_response :success
    assert_select "h1", text: "Test Lifecycle WF"
    assert_select "p", text: /Australia.*AUD/
    
    # Step 3: Create a new funder pool
    get "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/new"
    assert_response :success
    assert_select "form"
    assert_select "input[name='funder_pool[name]']"
    assert_select "input[name='funder_pool[amount]']"
    assert_select "input[name='funder_pool[allocated]']"
    assert_select "input[name='funder_pool[benchmark_rate]']"
    assert_select "input[name='funder_pool[margin_rate]']"
    # Check that the BBSW label is shown for AUD currency
    assert_select "label", text: /BBSW Rate/

    post "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools", params: {
      funder_pool: {
        name: "Test Lifecycle Pool",
        amount: "1000000.00",
        allocated: "0.00",
        benchmark_rate: "4.25",
        margin_rate: "2.50"
      }
    }
    assert_response :redirect
    
    # Should redirect back to wholesale funder show page
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Test Lifecycle WF"
    
    # Step 4: Check that the pool appears on the wholesale funder page
    assert_select "td", text: "Test Lifecycle Pool"
    assert_select "td", text: "$1,000,000.0"
    
    # Get the funder pool ID (assumes it's the first pool created)
    funder_pool_link = css_select("a[href*='/funder_pools/'][href*='/edit']").first
    funder_pool_id = funder_pool_link['href'].match(/funder_pools\/(\d+)/)[1] if funder_pool_link
    
    # Step 5: View the funder pool show page
    get "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/#{funder_pool_id}"
    assert_response :success
    assert_select "h3", text: /Pool Summary/
    assert_select ".detail-value", text: "Test Lifecycle WF"
    assert_select ".rate-value", text: "4.25%"
    assert_select ".rate-value", text: "2.5%"
    assert_select ".total-rate-value", text: "6.75%"
    assert_select ".detail-label", text: "BBSW Rate"
    
    # Step 6: Edit the funder pool
    get "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/#{funder_pool_id}/edit"
    assert_response :success
    assert_select "form"
    assert_select "input[value='Test Lifecycle Pool']"
    assert_select "input[value='1000000.0']"
    assert_select "input[value='4.25']"
    assert_select "input[value='2.5']"
    assert_select "label", text: /BBSW Rate/

    patch "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/#{funder_pool_id}", params: {
      funder_pool: {
        name: "Updated Lifecycle Pool",
        amount: "1500000.00",
        allocated: "100000.00", 
        benchmark_rate: "4.50",
        margin_rate: "3.00"
      }
    }
    assert_response :redirect
    
    # Should redirect to the pool show page
    follow_redirect!
    assert_response :success
    assert_select ".rate-value", text: "4.5%"
    assert_select ".rate-value", text: "3.0%"
    assert_select ".total-rate-value", text: "7.5%"
    
    # Step 7: Test editing the wholesale funder
    get "/admin/wholesale_funders/#{wholesale_funder_id}/edit"
    assert_response :success
    assert_select "input[value='Test Lifecycle WF']"
    assert_select "input[value='Australia']"
    
    patch "/admin/wholesale_funders/#{wholesale_funder_id}", params: {
      wholesale_funder: {
        name: "Updated Lifecycle WF",
        country: "Australia",
        currency: "AUD"
      }
    }
    assert_response :redirect
    
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Updated Lifecycle WF"
  end

  test "rate defaults work correctly for different currencies" do
    # Test USD currency defaults to SOFR
    post "/admin/wholesale_funders", params: {
      wholesale_funder: {
        name: "Test USD WF",
        country: "United States",
        currency: "USD"
      }
    }
    follow_redirect!
    wholesale_funder_id = request.path.match(/\/admin\/wholesale_funders\/(\d+)/)[1]
    
    get "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/new"
    assert_response :success
    assert_select "label", text: /SOFR Rate/
    
    # Test GBP currency defaults to SONIA
    post "/admin/wholesale_funders", params: {
      wholesale_funder: {
        name: "Test GBP WF", 
        country: "United Kingdom",
        currency: "GBP"
      }
    }
    follow_redirect!
    wholesale_funder_id = request.path.match(/\/admin\/wholesale_funders\/(\d+)/)[1]
    
    get "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools/new"
    assert_response :success
    assert_select "label", text: /SONIA Rate/
  end

  test "rate validation works correctly" do
    # Create a wholesale funder first
    post "/admin/wholesale_funders", params: {
      wholesale_funder: {
        name: "Test Validation WF",
        country: "Australia",
        currency: "AUD"
      }
    }
    follow_redirect!
    wholesale_funder_id = request.path.match(/\/admin\/wholesale_funders\/(\d+)/)[1]
    
    # Test negative benchmark rate validation
    post "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools", params: {
      funder_pool: {
        name: "Invalid Pool",
        amount: "100000.00",
        allocated: "0.00", 
        benchmark_rate: "-1.00",
        margin_rate: "2.00"
      }
    }
    assert_response :unprocessable_entity
    assert_select ".field-error", text: /must be greater than or equal to 0/
    
    # Test rate over 100% validation
    post "/admin/wholesale_funders/#{wholesale_funder_id}/funder_pools", params: {
      funder_pool: {
        name: "Invalid Pool 2",
        amount: "100000.00",
        allocated: "0.00",
        benchmark_rate: "101.00", 
        margin_rate: "2.00"
      }
    }
    assert_response :unprocessable_entity
    assert_select ".field-error", text: /must be less than or equal to 100/
  end
end