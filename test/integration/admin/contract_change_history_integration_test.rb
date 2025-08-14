require 'test_helper'

class Admin::ContractChangeHistoryIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts, :contract_versions

  def setup
    @admin = users(:admin_user)
    @contract = contracts(:active_contract)
    sign_in @admin
  end

  test "admin can view contract change history" do
    # Visit the contract show page
    get admin_contract_path(@contract)
    assert_response :success

    # Should show contract details
    assert_select 'h1', text: /Contract ##{@contract.id}/
    assert_select 'div.admin-field-value', text: /#{@contract.status.humanize}/

    # Should show change history section
    assert_select 'h3', text: 'Change History'
    assert_select 'div.versions-list'
    
    # Should show version entries from the page view we just created
    assert_select 'div.version-entry'
    assert_select 'div.version-meta', text: /#{@admin.display_name}/
  end

  test "admin updates create change history entries" do
    # Update contract status
    new_status = :in_arrears
    
    patch admin_contract_path(@contract), params: {
      contract: {
        status: new_status,
        start_date: @contract.start_date,
        end_date: @contract.end_date,
        application_id: @contract.application_id
      }
    }
    
    assert_redirected_to admin_contract_path(@contract)
    follow_redirect!
    assert_response :success
    
    # Should show the updated status
    assert_select 'span.status-badge', text: /In arrears/
    
    # Should show new change history entry
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'changed contract status'
      assert_select 'div.field-change', text: /Status:/
      assert_select 'span.change-to', text: 'In arrears'
    end
  end

  test "viewing contract creates view history entry" do
    initial_version_count = @contract.contract_versions.count
    
    get admin_contract_path(@contract)
    assert_response :success
    
    @contract.reload
    assert_equal initial_version_count + 1, @contract.contract_versions.count
    
    # Check the new version is a view action
    latest_version = @contract.contract_versions.recent.first
    assert_equal 'viewed', latest_version.action
    assert_equal @admin, latest_version.admin_user
  end

  test "changing contract dates creates update history" do
    new_start_date = Date.current + 2.months
    new_end_date = Date.current + 7.years
    
    patch admin_contract_path(@contract), params: {
      contract: {
        status: @contract.status,
        start_date: new_start_date,
        end_date: new_end_date,
        application_id: @contract.application_id
      }
    }
    
    assert_redirected_to admin_contract_path(@contract)
    follow_redirect!
    
    # Should show updated dates
    assert_select 'div.admin-field-value', text: /#{new_start_date.strftime("%B %d, %Y")}/
    assert_select 'div.admin-field-value', text: /#{new_end_date.strftime("%B %d, %Y")}/
    
    # Should show date changes in change history
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'updated contract information'
      assert_select 'div.field-change', text: /Start Date:/
      assert_select 'div.field-change', text: /End Date:/
    end
  end

  test "change history shows detailed field changes" do
    # Create a version with multiple field changes
    @contract.contract_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Multiple field update test',
      previous_status: 'awaiting_funding',
      new_status: 'ok',
      previous_start_date: Date.current,
      new_start_date: Date.current + 1.month,
      previous_end_date: Date.current + 5.years,
      new_end_date: Date.current + 6.years
    )
    
    get admin_contract_path(@contract)
    assert_response :success
    
    # Should show all field changes
    assert_select 'div.version-changes' do
      assert_select 'div.field-change', text: /Status:/
      assert_select 'div.field-change', text: /Start Date:/
      assert_select 'div.field-change', text: /End Date:/
      
      # Check change indicators
      assert_select 'span.change-from', text: 'Awaiting funding'
      assert_select 'span.change-to', text: 'Ok'
      assert_select 'span.change-arrow', text: '→'
    end
  end

  test "different actions have appropriate styling and descriptions" do
    # Create versions for different actions
    actions_to_test = [
      { action: 'created', description: 'created contract' },
      { action: 'updated', description: 'updated contract information' },
      { action: 'viewed', description: 'viewed contract' },
      { action: 'status_changed', description: 'changed contract status' }
    ]
    
    actions_to_test.each do |test_case|
      @contract.contract_versions.create!(
        admin_user: @admin,
        action: test_case[:action],
        change_details: "Test #{test_case[:action]} action"
      )
    end
    
    get admin_contract_path(@contract)
    assert_response :success
    
    actions_to_test.each do |test_case|
      assert_select 'span.version-action', text: test_case[:description]
    end
  end

  test "change history respects limit and shows recent entries first" do
    # Create many versions (more than the 20 limit in controller)
    25.times do |i|
      @contract.contract_versions.create!(
        admin_user: @admin,
        action: 'viewed',
        change_details: "Test view #{i}",
        created_at: i.hours.ago
      )
    end
    
    get admin_contract_path(@contract)
    assert_response :success
    
    # Should only show 20 entries (as per controller limit)
    version_entries = css_select('div.version-entry')
    assert_operator version_entries.length, :<=, 20
    
    # Should show most recent first - check that we have entries in descending order
    # The most recent entry should be a 'viewed' action from our current page view
    assert_select 'div.version-entry:first-child' do
      assert_select 'span.version-action', text: 'viewed contract'
    end
  end

  test "creating new contract shows creation history" do
    # Create a unique application for testing
    unique_application = Application.create!(
      user: users(:jane),
      address: '777 History Street, History City, HC 77777',
      home_value: 650000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 48
    )
    
    # Create the contract
    post admin_contracts_path, params: {
      contract: {
        application_id: unique_application.id,
        status: 'awaiting_funding',
        start_date: Date.current,
        end_date: Date.current + 5.years
      }
    }
    
    new_contract = Contract.last
    assert_redirected_to admin_contract_path(new_contract)
    follow_redirect!
    
    # Should show creation in change history
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'created contract'
      assert_select 'div.version-details', text: /Created contract for/
    end
  end

  test "status changes show before and after values" do
    old_status = @contract.status
    new_status = :complete
    
    patch admin_contract_path(@contract), params: {
      contract: {
        status: new_status,
        start_date: @contract.start_date,
        end_date: @contract.end_date,
        application_id: @contract.application_id
      }
    }
    
    follow_redirect!
    
    # Should show status change with before/after values
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'changed contract status'
      assert_select 'div.field-change' do
        assert_select 'span.field-name', text: 'Status:'
        assert_select 'span.change-from', text: old_status.humanize
        assert_select 'span.change-to', text: new_status.to_s.humanize
      end
    end
  end

  test "change history shows formatted dates" do
    # Create a version with date changes
    test_start_date = Date.new(2024, 6, 15)
    test_end_date = Date.new(2029, 6, 15)
    
    @contract.contract_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Date update test',
      previous_start_date: Date.current,
      new_start_date: test_start_date,
      previous_end_date: Date.current + 5.years,
      new_end_date: test_end_date
    )
    
    get admin_contract_path(@contract)
    assert_response :success
    
    # Should show formatted dates
    assert_select 'div.field-change' do
      assert_select 'span.change-from', text: Date.current.strftime("%B %d, %Y")
      assert_select 'span.change-to', text: test_start_date.strftime("%B %d, %Y")
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end