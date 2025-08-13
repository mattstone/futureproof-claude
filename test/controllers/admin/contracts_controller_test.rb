require 'test_helper'

class Admin::ContractsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts

  def setup
    @admin = users(:admin_user)
    sign_in @admin

    @contract = contracts(:active_contract)
    @application_without_contract = applications(:mortgage_application)
    
    # Ensure application is accepted so it can have a contract
    @application_without_contract.update!(status: :accepted)
    
    # Create a unique application for testing creation without conflicts
    @unique_application = Application.create!(
      user: users(:jane),
      address: '999 Test Street, Test City, TS 12345',
      home_value: 600000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 45
    )
  end

  test "should get index" do
    get admin_contracts_path
    assert_response :success
    assert_select 'h1', /Contracts/
    assert_select '.admin-table table'
  end

  test "should show contract" do
    get admin_contract_path(@contract)
    assert_response :success
    assert_select 'h1', /Contract ##{@contract.id}/
    assert_match @contract.application.user.display_name, response.body
    assert_match @contract.application.address, response.body
  end

  test "should get new contract form" do
    get new_admin_contract_path
    assert_response :success
    assert_select 'form[action=?]', admin_contracts_path
    assert_select 'select[name="contract[application_id]"]'
    assert_select 'select[name="contract[status]"]'
    assert_select 'input[name="contract[start_date]"]'
    assert_select 'input[name="contract[end_date]"]'
  end

  test "should create contract" do
    assert_difference('Contract.count') do
      post admin_contracts_path, params: {
        contract: {
          application_id: @unique_application.id,
          status: 'awaiting_funding',
          start_date: Date.current,
          end_date: Date.current + 5.years
        }
      }
    end

    contract = Contract.last
    assert_redirected_to admin_contract_path(contract)
    assert_equal 'awaiting_funding', contract.status
    assert_equal @unique_application.id, contract.application_id
  end

  test "should not create contract with invalid params" do
    assert_no_difference('Contract.count') do
      post admin_contracts_path, params: {
        contract: {
          application_id: '',
          status: 'awaiting_funding',
          start_date: Date.current,
          end_date: Date.current - 1.day # Invalid: end before start
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select '.admin-error-messages'
  end

  test "should get edit contract form" do
    get edit_admin_contract_path(@contract)
    assert_response :success
    assert_select 'form[action=?]', admin_contract_path(@contract)
    assert_select 'select[name="contract[application_id]"]'
    assert_select 'select[name="contract[status]"]'
  end

  test "should update contract" do
    new_status = 'ok'
    new_start_date = Date.current + 1.month
    
    patch admin_contract_path(@contract), params: {
      contract: {
        status: new_status,
        start_date: new_start_date,
        end_date: @contract.end_date,
        application_id: @contract.application_id
      }
    }

    assert_redirected_to admin_contract_path(@contract)
    @contract.reload
    assert_equal new_status, @contract.status
    assert_equal new_start_date, @contract.start_date
  end

  test "should not update contract with invalid params" do
    old_status = @contract.status
    
    patch admin_contract_path(@contract), params: {
      contract: {
        status: old_status,
        start_date: Date.current,
        end_date: Date.current - 1.day, # Invalid: end before start
        application_id: @contract.application_id
      }
    }

    assert_response :unprocessable_entity
    assert_select '.admin-error-messages'
    
    @contract.reload
    assert_equal old_status, @contract.status
  end

  test "should destroy contract" do
    assert_difference('Contract.count', -1) do
      delete admin_contract_path(@contract)
    end

    assert_redirected_to admin_contracts_path
    assert_match 'successfully deleted', flash[:notice]
  end

  test "should filter contracts by status" do
    # Create another unique application for status filtering test
    status_test_app = Application.create!(
      user: users(:john),
      address: '888 Status Street, Status City, ST 11111',
      home_value: 700000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 50
    )
    
    # Create contracts with different statuses
    ok_contract = Contract.create!(
      application: status_test_app,
      status: :ok,
      start_date: Date.current,
      end_date: Date.current + 3.years
    )

    get admin_contracts_path, params: { status: 'ok' }
    assert_response :success
    
    # Should show the ok contract
    assert_match "status-ok", response.body
    assert_match ok_contract.application.user.display_name, response.body
  end

  test "should search contracts by customer name" do
    customer_name = @contract.application.user.first_name
    
    get admin_contracts_path, params: { search: customer_name }
    assert_response :success
    
    # Should find the contract with matching customer name
    assert_match @contract.application.user.display_name, response.body
    assert_match @contract.application.address, response.body
  end

  test "should search contracts by property address" do
    address_part = @contract.application.address.split.first
    
    get admin_contracts_path, params: { search: address_part }
    assert_response :success
    
    # Should find the contract with matching address
    assert_match @contract.application.address, response.body
  end

  test "should only show accepted applications in new contract form" do
    # Create applications with different statuses
    submitted_app = Application.create!(
      user: users(:john),
      address: '999 Submitted Street',
      home_value: 500000,
      status: :submitted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 40
    )

    get new_admin_contract_path
    assert_response :success
    
    # Should show accepted application
    assert_match @unique_application.address, response.body
    
    # Should not show submitted application
    assert_no_match submitted_app.address, response.body
  end

  test "should not allow creating contract for application that already has one" do
    existing_application = @contract.application
    
    assert_no_difference('Contract.count') do
      post admin_contracts_path, params: {
        contract: {
          application_id: existing_application.id,
          status: 'awaiting_funding',
          start_date: Date.current,
          end_date: Date.current + 5.years
        }
      }
    end

    assert_response :unprocessable_entity
    # Should handle the unique constraint violation gracefully
    follow_redirect! if response.status == 302
  end

  test "should require admin authentication" do
    sign_out @admin
    
    get admin_contracts_path
    assert_redirected_to new_user_session_path
    
    get admin_contract_path(@contract)
    assert_redirected_to new_user_session_path
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end

  def sign_out(user)
    delete destroy_user_session_path
  end
end