require 'test_helper'

class Admin::ContractsSearchFilterTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts

  def setup
    @admin = users(:admin_user)
    sign_in @admin

    # Create applications for contract testing
    @app_for_search_1 = Application.create!(
      user: users(:john),
      address: '123 Contract Street, Search City, SC 12345',
      home_value: 600000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 55
    )

    @app_for_search_2 = Application.create!(
      user: users(:jane),
      address: '456 Agreement Avenue, Contract Town, CT 67890',
      home_value: 800000,
      status: :accepted,
      ownership_status: :joint,
      property_state: :investment,
      borrower_age: 60,
      borrower_names: '[{"name":"Jane Smith","age":60},{"name":"Bob Jones","age":62}]'
    )

    @app_for_different = Application.create!(
      user: users(:john),
      address: '789 Different Drive, Other Place, OP 11111',
      home_value: 450000,
      status: :accepted,
      ownership_status: :company,
      property_state: :holiday,
      borrower_age: 40,
      company_name: 'Different Corp Ltd'
    )

    # Create contracts with different statuses for testing
    @searchable_contract_1 = Contract.create!(
      application: @app_for_search_1,
      status: :awaiting_funding,
      start_date: Date.current,
      end_date: Date.current + 5.years
    )

    @searchable_contract_2 = Contract.create!(
      application: @app_for_search_2,
      status: :ok,
      start_date: Date.current - 1.year,
      end_date: Date.current + 4.years
    )

    @different_contract = Contract.create!(
      application: @app_for_different,
      status: :in_arrears,
      start_date: Date.current - 6.months,
      end_date: Date.current + 4.years + 6.months
    )

    @holiday_contract = Contract.create!(
      application: Application.create!(
        user: users(:jane),
        address: '999 Holiday Lane, Vacation City, VC 99999',
        home_value: 750000,
        status: :accepted,
        ownership_status: :individual,
        property_state: :holiday,
        borrower_age: 65
      ),
      status: :in_holiday,
      start_date: Date.current - 2.months,
      end_date: Date.current + 3.years
    )

    @complete_contract = Contract.create!(
      application: Application.create!(
        user: users(:john),
        address: '111 Complete Court, Finished City, FC 11111',
        home_value: 500000,
        status: :accepted,
        ownership_status: :super,
        property_state: :primary_residence,
        borrower_age: 70,
        super_fund_name: 'Complete Super Fund'
      ),
      status: :complete,
      start_date: Date.current - 3.years,
      end_date: Date.current - 1.month
    )
  end

  test "should have dynamic search input with oninput attribute using POST" do
    get admin_contracts_path
    assert_response :success
    
    # Check that the search form uses POST to search action with Turbo Stream
    assert_select 'form[action="/admin/contracts/search"][method="post"][data-turbo-stream="true"]'
    assert_select 'input[name="search"][oninput="this.form.requestSubmit();"]'
  end

  test "should have dynamic status filter with onchange attribute using POST" do
    get admin_contracts_path
    assert_response :success
    
    # Check that the filter form uses POST to search action with Turbo Stream
    assert_select 'form[action="/admin/contracts/search"][method="post"][data-turbo-stream="true"]'
    assert_select 'select[name="status"][onchange="this.form.requestSubmit();"]'
  end

  test "should handle search via POST request with turbo stream" do
    post search_admin_contracts_path, params: { search: users(:john).first_name },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    # Should return turbo stream response that updates the results frame
    assert_response :success
    assert_match "turbo-stream", response.headers["Content-Type"]
    assert_includes response.body, '<turbo-stream action="replace" target="contracts_results">'
  end

  test "should have turbo frame wrapping results" do
    get admin_contracts_path
    assert_response :success
    
    # Check that results are wrapped in turbo frame
    assert_select 'turbo-frame[id="contracts_results"]'
    assert_select 'turbo-frame[id="contracts_results"] .admin-table'
  end

  test "should have action links that break out of turbo frame" do
    get admin_contracts_path
    assert_response :success
    
    # Check that action links have data-turbo-frame="_top" to break out of frame
    assert_select 'turbo-frame[id="contracts_results"] a[data-turbo-frame="_top"]'
  end

  test "should search contracts by customer first name" do
    get admin_contracts_path, params: { search: users(:john).first_name }
    assert_response :success
    
    # Should find contracts for applications by John
    assert_match @searchable_contract_1.application.address, response.body
    assert_match @different_contract.application.address, response.body
    assert_match @complete_contract.application.address, response.body
    
    # Should not find contracts for applications by Jane
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
  end

  test "should search contracts by customer last name" do
    get admin_contracts_path, params: { search: users(:jane).last_name }
    assert_response :success
    
    # Should find contracts for applications by Jane
    assert_match @searchable_contract_2.application.address, response.body
    assert_match @holiday_contract.application.address, response.body
    
    # Should not find contracts for applications by John
    assert_no_match @searchable_contract_1.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should search contracts by customer email" do
    get admin_contracts_path, params: { search: users(:john).email }
    assert_response :success
    
    # Should find contracts for applications by John
    assert_match @searchable_contract_1.application.address, response.body
    assert_match @different_contract.application.address, response.body
    assert_match @complete_contract.application.address, response.body
    
    # Should not find contracts for applications by Jane
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
  end

  test "should search contracts by property address" do
    get admin_contracts_path, params: { search: 'Contract Street' }
    assert_response :success
    
    # Should find the matching address
    assert_match @searchable_contract_1.application.address, response.body
    
    # Should not find other addresses
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should search contracts case insensitively" do
    get admin_contracts_path, params: { search: 'CONTRACT' }
    assert_response :success
    
    # Should find the matching address regardless of case
    assert_match @searchable_contract_1.application.address, response.body
  end

  test "should filter contracts by status awaiting_funding" do
    get admin_contracts_path, params: { status: 'awaiting_funding' }
    assert_response :success
    
    # Should find awaiting_funding contract
    assert_match @searchable_contract_1.application.address, response.body
    
    # Should not find other status contracts
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should filter contracts by status ok" do
    get admin_contracts_path, params: { status: 'ok' }
    assert_response :success
    
    # Should find ok status contract
    assert_match @searchable_contract_2.application.address, response.body
    
    # Should not find other status contracts
    assert_no_match @searchable_contract_1.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should filter contracts by status in_arrears" do
    get admin_contracts_path, params: { status: 'in_arrears' }
    assert_response :success
    
    # Should find in_arrears contract
    assert_match @different_contract.application.address, response.body
    
    # Should not find other status contracts
    assert_no_match @searchable_contract_1.application.address, response.body
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should filter contracts by status in_holiday" do
    get admin_contracts_path, params: { status: 'in_holiday' }
    assert_response :success
    
    # Should find in_holiday contract
    assert_match @holiday_contract.application.address, response.body
    
    # Should not find other status contracts
    assert_no_match @searchable_contract_1.application.address, response.body
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
  end

  test "should filter contracts by status complete" do
    get admin_contracts_path, params: { status: 'complete' }
    assert_response :success
    
    # Should find complete contract
    assert_match @complete_contract.application.address, response.body
    
    # Should not find other status contracts
    assert_no_match @searchable_contract_1.application.address, response.body
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
  end

  test "should combine search and status filter" do
    get admin_contracts_path, params: { search: users(:john).first_name, status: 'awaiting_funding' }
    assert_response :success
    
    # Should find John's awaiting_funding contract
    assert_match @searchable_contract_1.application.address, response.body
    
    # Should not find John's other contracts (wrong status)
    assert_no_match @different_contract.application.address, response.body
    assert_no_match @complete_contract.application.address, response.body
    
    # Should not find Jane's contracts (wrong user)
    assert_no_match @searchable_contract_2.application.address, response.body
    assert_no_match @holiday_contract.application.address, response.body
  end

  test "should preserve search when filtering by status" do
    get admin_contracts_path, params: { search: users(:john).first_name, status: 'awaiting_funding' }
    assert_response :success
    
    # Check that both search and status parameters are preserved in forms
    assert_select 'input[name="search"][value=?]', users(:john).first_name
    assert_select 'select[name="status"] option[selected="selected"][value="awaiting_funding"]'
  end

  test "should preserve status when searching" do
    get admin_contracts_path, params: { search: 'Contract', status: 'ok' }
    assert_response :success
    
    # Check that both search and status parameters are preserved in forms
    assert_select 'input[name="search"][value="Contract"]'
    assert_select 'select[name="status"] option[selected="selected"][value="ok"]'
  end

  test "should show all contract status options" do
    get admin_contracts_path
    assert_response :success
    
    # Should have all contract status options
    assert_select 'select[name="status"] option[value="awaiting_funding"]'
    assert_select 'select[name="status"] option[value="awaiting_investment"]'
    assert_select 'select[name="status"] option[value="ok"]'
    assert_select 'select[name="status"] option[value="in_holiday"]'
    assert_select 'select[name="status"] option[value="in_arrears"]'
    assert_select 'select[name="status"] option[value="complete"]'
    
    # Should have "All Statuses" option
    assert_select 'select[name="status"] option[value=""]', text: 'All Statuses'
  end

  test "should handle empty search results" do
    get admin_contracts_path, params: { search: 'NonexistentSearchTerm12345' }
    assert_response :success
    
    # Should show empty state message
    assert_match 'No contracts found matching', response.body
  end

  test "should handle empty filter results" do
    get admin_contracts_path, params: { status: 'awaiting_investment' }
    assert_response :success
    
    # Should show empty state message or no results
    # (awaiting_investment status not used in our test data)
    assert_match 'No contracts found with status', response.body
  end

  test "should handle search with partial address match" do
    get admin_contracts_path, params: { search: 'Agreement' }
    assert_response :success
    
    # Should find contract with matching address part
    assert_match @searchable_contract_2.application.address, response.body
    
    # Should not find contracts without matching address
    assert_no_match @searchable_contract_1.application.address, response.body
  end

  test "should handle search with partial customer name match" do
    partial_name = users(:jane).first_name[0..2] # First 3 characters
    get admin_contracts_path, params: { search: partial_name }
    assert_response :success
    
    # Should find contracts for Jane if the partial name matches
    if users(:jane).first_name.downcase.include?(partial_name.downcase)
      assert_match @searchable_contract_2.application.address, response.body
      assert_match @holiday_contract.application.address, response.body
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end