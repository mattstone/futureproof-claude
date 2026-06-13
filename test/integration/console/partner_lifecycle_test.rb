require "test_helper"

class Console::PartnerLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @lender = lenders(:broker)
    @funder = wholesale_funders(:one)
  end

  test "suspend requires a reason and audits" do
    patch suspend_console_lender_path(@lender), params: { reason: "" }
    assert_match(/reason is required/, flash[:alert])
    assert @lender.reload.status_active?

    assert_difference -> { AuditLog.where(action: "partner_suspended").count }, 1 do
      patch suspend_console_lender_path(@lender), params: { reason: "Agreement lapsed" }
    end
    assert @lender.reload.status_suspended?
    assert_equal "Agreement lapsed", AuditLog.where(action: "partner_suspended").last.reason
  end

  test "reactivate flips back with audit" do
    @lender.update_column(:status, Lender.statuses[:suspended])

    assert_difference -> { AuditLog.where(action: "partner_reactivated").count }, 1 do
      patch reactivate_console_lender_path(@lender), params: { reason: "New agreement executed" }
    end
    assert @lender.reload.status_active?
  end

  test "the futureproof house lender cannot be suspended" do
    house = lenders(:futureproof)
    patch suspend_console_lender_path(house), params: { reason: "should not work" }
    assert_match(/cannot be suspended/, flash[:alert])
    assert house.reload.status_active?
  end

  test "suspended lenders disappear from the approval picker" do
    @lender.update_column(:status, Lender.statuses[:suspended])
    application = applications(:submitted_application)
    # PL-1: the approve form (and its lender picker) only renders once
    # compliance is cleared.
    KycSubmission.find_or_initialize_by(application: application)
                 .update!(status: :verified, verification_type: "government_id",
                          verified_at: Time.current, verified_by: users(:admin_user).display_name)
    AmlCheck.find_or_initialize_by(application: application)
            .update!(status: :passed, checked_at: Time.current, passed_at: Time.current)

    get console_application_path(application)
    assert_response :success
    assert_select "select#lender_id option", { text: @lender.name, count: 0 }
    assert_select "select#lender_id option", text: lenders(:futureproof).name
  end

  test "suspended funders disappear from the lender funding picker" do
    funder = WholesaleFunder.status_active.where.not(id: @lender.wholesale_funders.select(:id)).first
    assert funder, "needs an unlinked active funder"
    funder.update_column(:status, WholesaleFunder.statuses[:suspended])

    get console_lender_path(@lender)
    assert_select "select#wholesale_funder_id option", { text: funder.name, count: 0 }
  end

  test "wholesale funder suspend and reactivate" do
    assert_difference -> { AuditLog.where(action: "partner_suspended").count }, 1 do
      patch suspend_console_wholesale_funder_path(@funder), params: { reason: "Facility expired" }
    end
    assert @funder.reload.status_suspended?

    get console_wholesale_funder_path(@funder)
    assert_select ".console-badge", text: "Suspended"

    patch reactivate_console_wholesale_funder_path(@funder), params: { reason: "Renewed" }
    assert @funder.reload.status_active?
  end

  test "indexes show suspended state" do
    @lender.update_column(:status, Lender.statuses[:suspended])
    get console_lenders_path
    assert_select ".console-badge", text: "Suspended"
  end
end
