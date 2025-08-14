require 'test_helper'

class ContractChangeTrackingTest < ActiveSupport::TestCase
  fixtures :users, :applications, :contracts

  def setup
    @admin = users(:admin_user)
    @application = applications(:mortgage_application)
    @contract = contracts(:active_contract)
  end

  test "should log creation when admin creates contract" do
    # Create a unique application for this test
    unique_application = Application.create!(
      user: users(:jane),
      address: '123 Creation Test Street, Test City, TC 12345',
      home_value: 500000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 45
    )
    
    new_contract = Contract.new(
      application: unique_application,
      status: :awaiting_funding,
      start_date: Date.current,
      end_date: Date.current + 5.years
    )
    new_contract.current_admin_user = @admin
    
    assert_difference 'ContractVersion.count', 1 do
      new_contract.save!
    end
    
    creation_version = new_contract.contract_versions.last
    assert_equal 'created', creation_version.action
    assert_equal @admin, creation_version.admin_user
    assert_includes creation_version.change_details, 'Created contract'
    assert_equal 'awaiting_funding', creation_version.new_status
    assert_equal Date.current, creation_version.new_start_date.to_date
    assert_equal unique_application.id, creation_version.new_application_id
  end

  test "should not log creation when no admin user present" do
    # Create another unique application for this test
    unique_application2 = Application.create!(
      user: users(:john),
      address: '456 No Admin Test Street, Test City, TC 67890',
      home_value: 600000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 50
    )
    
    new_contract = Contract.new(
      application: unique_application2,
      status: :awaiting_funding,
      start_date: Date.current,
      end_date: Date.current + 5.years
    )
    # No current_admin_user set
    
    assert_no_difference 'ContractVersion.count' do
      new_contract.save!
    end
  end

  test "should log update when admin updates contract" do
    @contract.current_admin_user = @admin
    
    assert_difference '@contract.contract_versions.count', 1 do
      @contract.update!(status: :in_arrears)
    end
    
    update_version = @contract.contract_versions.last
    assert_equal 'status_changed', update_version.action
    assert_equal @admin, update_version.admin_user
    assert_includes update_version.change_details, 'Changed status'
    assert_equal @contract.status_before_last_save, update_version.previous_status
    assert_equal 'in_arrears', update_version.new_status
  end

  test "should not log update when no changes made" do
    @contract.current_admin_user = @admin
    
    assert_no_difference '@contract.contract_versions.count' do
      @contract.save! # No actual changes
    end
  end

  test "should not log update when no admin user present" do
    # No current_admin_user set
    
    assert_no_difference '@contract.contract_versions.count' do
      @contract.update!(status: :complete)
    end
  end

  test "should log status change with special action" do
    @contract.current_admin_user = @admin
    
    assert_difference '@contract.contract_versions.count', 1 do
      @contract.update!(status: :complete)
    end
    
    status_version = @contract.contract_versions.last
    assert_equal 'status_changed', status_version.action
    assert_includes status_version.change_details, 'Changed status'
    assert_includes status_version.change_details, 'Complete'
    assert_equal @contract.status_before_last_save, status_version.previous_status
    assert_equal 'complete', status_version.new_status
  end

  test "should build comprehensive change summary" do
    @contract.current_admin_user = @admin
    
    new_start_date = Date.current + 1.month
    new_end_date = Date.current + 6.years
    
    @contract.update!(
      start_date: new_start_date,
      end_date: new_end_date
    )
    
    update_version = @contract.contract_versions.last
    change_details = update_version.change_details
    
    assert_includes change_details, 'Start date changed'
    assert_includes change_details, 'End date changed'
  end

  test "should handle date formatting in changes" do
    @contract.current_admin_user = @admin
    
    old_start = @contract.start_date
    new_start = Date.current + 1.month
    
    @contract.update!(start_date: new_start)
    
    update_version = @contract.contract_versions.last
    assert_includes update_version.change_details, old_start.strftime("%B %d, %Y")
    assert_includes update_version.change_details, new_start.strftime("%B %d, %Y")
  end

  test "should log view action" do
    assert_difference '@contract.contract_versions.count', 1 do
      @contract.log_view_by(@admin)
    end
    
    view_version = @contract.contract_versions.last
    assert_equal 'viewed', view_version.action
    assert_equal @admin, view_version.admin_user
    assert_includes view_version.change_details, @admin.display_name
    assert_includes view_version.change_details, 'viewed contract'
  end

  test "should not log view action for non-admin user" do
    regular_user = users(:jane)
    regular_user.update!(admin: false) # Ensure not admin
    
    assert_no_difference '@contract.contract_versions.count' do
      @contract.log_view_by(regular_user)
    end
  end

  test "should not log view action when user is nil" do
    assert_no_difference '@contract.contract_versions.count' do
      @contract.log_view_by(nil)
    end
  end

  test "should track application changes" do
    @contract.current_admin_user = @admin
    
    # Create a new application for testing application changes
    new_application = Application.create!(
      user: users(:jane),
      address: '789 Application Change Street, Test City, TC 11111',
      home_value: 700000,
      status: :accepted,
      ownership_status: :individual,
      property_state: :primary_residence,
      borrower_age: 55
    )
    
    old_application_id = @contract.application_id
    
    assert_difference '@contract.contract_versions.count', 1 do
      @contract.update!(application: new_application)
    end
    
    update_version = @contract.contract_versions.last
    assert_includes update_version.change_details, 'Application changed'
    assert_equal old_application_id, update_version.previous_application_id
    assert_equal new_application.id, update_version.new_application_id
  end

  test "should handle multiple field updates in single version" do
    @contract.current_admin_user = @admin
    
    old_status = @contract.status
    old_start_date = @contract.start_date
    
    new_start_date = Date.current + 2.months
    
    @contract.update!(
      status: :in_holiday,
      start_date: new_start_date
    )
    
    update_version = @contract.contract_versions.last
    
    # Should be status_changed since status change takes priority
    assert_equal 'status_changed', update_version.action
    
    # Check all fields are captured
    assert_equal old_status, update_version.previous_status
    assert_equal 'in_holiday', update_version.new_status
    assert_equal old_start_date, update_version.previous_start_date&.to_date
    assert_equal new_start_date, update_version.new_start_date&.to_date
  end

  test "should prioritize status_changed action for status-only updates" do
    @contract.current_admin_user = @admin
    
    @contract.update!(status: :in_arrears)
    
    update_version = @contract.contract_versions.last
    assert_equal 'status_changed', update_version.action
    assert_includes update_version.change_details, 'Changed status from'
  end

  test "should use updated action for non-status changes" do
    @contract.current_admin_user = @admin
    
    @contract.update!(start_date: Date.current + 1.week)
    
    update_version = @contract.contract_versions.last
    assert_equal 'updated', update_version.action
    assert_includes update_version.change_details, 'Start date changed'
  end

  test "should track end date changes" do
    @contract.current_admin_user = @admin
    
    old_end_date = @contract.end_date
    new_end_date = Date.current + 10.years
    
    @contract.update!(end_date: new_end_date)
    
    update_version = @contract.contract_versions.last
    assert_includes update_version.change_details, 'End date changed'
    assert_equal old_end_date, update_version.previous_end_date&.to_date
    assert_equal new_end_date, update_version.new_end_date&.to_date
  end
end