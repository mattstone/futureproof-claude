require 'test_helper'

class ContractVersionTest < ActiveSupport::TestCase
  fixtures :users, :applications, :contracts

  def setup
    @admin = users(:admin_user)
    @contract = contracts(:active_contract)
    @contract_version = @contract.contract_versions.build(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Test update'
    )
  end

  test "should belong to contract and admin_user" do
    assert_respond_to @contract_version, :contract
    assert_respond_to @contract_version, :admin_user
    assert_equal @contract, @contract_version.contract
    assert_equal @admin, @contract_version.admin_user
  end

  test "should validate action presence and inclusion" do
    version = ContractVersion.new
    assert_not version.valid?
    assert_includes version.errors[:action], "can't be blank"

    version.action = "invalid_action"
    assert_not version.valid?
    assert_includes version.errors[:action], "is not included in the list"

    valid_actions = %w[created updated viewed status_changed]
    valid_actions.each do |action|
      version.action = action
      version.contract = @contract
      version.admin_user = @admin
      assert version.valid?, "Action '#{action}' should be valid"
    end
  end

  test "should provide correct action descriptions" do
    version = ContractVersion.new
    
    assert_equal 'created contract', version.tap { |v| v.action = 'created' }.action_description
    assert_equal 'updated contract information', version.tap { |v| v.action = 'updated' }.action_description
    assert_equal 'viewed contract', version.tap { |v| v.action = 'viewed' }.action_description
    assert_equal 'changed contract status', version.tap { |v| v.action = 'status_changed' }.action_description
    assert_equal 'custom_action', version.tap { |v| v.action = 'custom_action' }.action_description
  end

  test "should format created_at correctly" do
    version = ContractVersion.create!(
      contract: @contract,
      admin_user: @admin,
      action: 'viewed',
      created_at: DateTime.new(2024, 8, 15, 14, 30, 0)
    )
    
    assert_equal "August 15, 2024 at 02:30 PM", version.formatted_created_at
  end

  test "should detect status changes correctly" do
    version = ContractVersion.new(
      previous_status: "awaiting_funding",
      new_status: "ok"
    )
    
    assert version.has_status_changes?
    
    version = ContractVersion.new(
      previous_status: "ok",
      new_status: "ok"
    )
    assert_not version.has_status_changes?
  end

  test "should detect date changes correctly" do
    version = ContractVersion.new(
      previous_start_date: Date.current.to_datetime,
      new_start_date: (Date.current + 1.day).to_datetime
    )
    
    assert version.has_start_date_changes?
    assert version.has_date_changes?
    
    version = ContractVersion.new(
      previous_end_date: (Date.current + 1.year).to_datetime,
      new_end_date: (Date.current + 2.years).to_datetime
    )
    
    assert version.has_end_date_changes?
    assert version.has_date_changes?
  end

  test "should detect application changes correctly" do
    version = ContractVersion.new(
      previous_application_id: 1,
      new_application_id: 2
    )
    
    assert version.has_application_changes?
    
    version = ContractVersion.new(
      previous_application_id: 1,
      new_application_id: 1
    )
    assert_not version.has_application_changes?
  end

  test "should generate detailed changes correctly" do
    today = Date.current
    tomorrow = Date.current + 1.day
    
    version = ContractVersion.new(
      previous_status: "awaiting_funding",
      new_status: "ok",
      previous_start_date: today.to_datetime,
      new_start_date: tomorrow.to_datetime,
      previous_application_id: 1,
      new_application_id: 2
    )
    
    changes = version.detailed_changes
    
    assert_equal 3, changes.length
    
    status_change = changes.find { |c| c[:field] == 'Status' }
    assert_equal "Awaiting funding", status_change[:from]
    assert_equal "Ok", status_change[:to]
    
    date_change = changes.find { |c| c[:field] == 'Start Date' }
    assert_equal today.strftime("%B %d, %Y"), date_change[:from]
    assert_equal tomorrow.strftime("%B %d, %Y"), date_change[:to]
    
    app_change = changes.find { |c| c[:field] == 'Application' }
    assert_equal "Application #1", app_change[:from]
    assert_equal "Application #2", app_change[:to]
  end

  test "should have working scopes" do
    # Create test versions
    recent_version = ContractVersion.create!(
      contract: @contract,
      admin_user: @admin,
      action: 'status_changed',
      created_at: 1.hour.ago
    )
    
    old_version = ContractVersion.create!(
      contract: @contract,
      admin_user: @admin,
      action: 'viewed', 
      created_at: 1.day.ago
    )
    
    # Test recent scope (ordered by created_at desc)
    recent_versions = ContractVersion.recent.limit(2)
    assert_equal recent_version, recent_versions.first
    
    # Test by_action scope
    status_versions = ContractVersion.by_action('status_changed')
    assert_includes status_versions, recent_version
    assert_not_includes status_versions, old_version
    
    # Test changes_only scope (excludes 'viewed')
    changes_versions = ContractVersion.changes_only
    assert_includes changes_versions, recent_version
    assert_not_includes changes_versions, old_version
    
    # Test views_only scope
    view_versions = ContractVersion.views_only
    assert_includes view_versions, old_version
    assert_not_includes view_versions, recent_version
  end

  test "should handle empty dates gracefully" do
    version = ContractVersion.new(
      previous_start_date: nil,
      new_start_date: Date.today
    )
    
    assert_not version.has_start_date_changes?
    
    changes = version.detailed_changes
    assert_empty changes
  end

  test "should format dates correctly in changes" do
    test_date = Date.new(2024, 12, 25)
    version = ContractVersion.new(
      previous_start_date: test_date,
      new_start_date: test_date + 1.day
    )
    
    changes = version.detailed_changes
    date_change = changes.first
    
    assert_equal "December 25, 2024", date_change[:from]
    assert_equal "December 26, 2024", date_change[:to]
  end
end