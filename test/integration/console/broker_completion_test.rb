require "test_helper"

class Console::BrokerCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @broker = brokers(:one)
  end

  # --- Record completeness -------------------------------------------------------

  test "edit captures firm and accreditation; show displays them" do
    patch console_broker_path(@broker), params: {
      broker: {
        name: @broker.name, email: @broker.email, jurisdiction: @broker.jurisdiction,
        firm_name: "Marsh & Co Lending", accreditation_ref: "MFAA 88231"
      }
    }
    assert_redirected_to console_broker_path(@broker)

    @broker.reload
    assert_equal "MFAA 88231", @broker.accreditation_ref

    get console_broker_path(@broker)
    assert_select ".console-dl-value", text: "Marsh & Co Lending"
    assert_select ".console-dl-value", text: "MFAA 88231"
  end

  # --- Lifecycle: pending → active → suspended → active ---------------------------

  test "console-created brokers start pending and are excluded from active pickers" do
    post console_brokers_path, params: {
      broker: { name: "Pending Broker", email: "pending-broker@example.com", jurisdiction: "AU" }
    }
    broker = Broker.find_by(email: "pending-broker@example.com")
    assert broker.status_pending?
    assert_not broker.active?
    assert_not_includes Broker.active, broker
  end

  test "activate takes a pending broker live, audited" do
    @broker.update_columns(status: Broker.statuses[:pending], active: false)

    assert_difference -> { AuditLog.where(action: "partner_activated").count }, 1 do
      patch activate_console_broker_path(@broker)
    end

    @broker.reload
    assert @broker.status_active?
    assert @broker.active?
    assert_includes Broker.active, @broker
  end

  test "suspend requires a reason, audits, and excludes the broker from active pickers" do
    patch suspend_console_broker_path(@broker)
    assert_match(/reason is required/, flash[:alert])
    assert @broker.reload.status_active?

    assert_difference -> { AuditLog.where(action: "partner_suspended").count }, 1 do
      patch suspend_console_broker_path(@broker), params: { reason: "Accreditation lapsed" }
    end

    @broker.reload
    assert @broker.status_suspended?
    assert_not @broker.active?
    assert_not_includes Broker.active, @broker

    get console_broker_path(@broker)
    assert_match "Suspended — existing applications continue; no new referrals", response.body
  end

  test "reactivate requires a reason and audits" do
    @broker.update_columns(status: Broker.statuses[:suspended], active: false)

    assert_difference -> { AuditLog.where(action: "partner_reactivated").count }, 1 do
      patch reactivate_console_broker_path(@broker), params: { reason: "Accreditation renewed" }
    end
    assert @broker.reload.status_active?
  end

  test "old-admin boolean flip still drives the status enum" do
    @broker.update!(active: false)
    assert @broker.reload.status_suspended?

    @broker.update!(active: true)
    assert @broker.reload.status_active?
  end

  # --- Performance -----------------------------------------------------------------

  test "performance card shows rolling windows, approval rate and commission" do
    get console_broker_path(@broker)
    assert_select ".console-card-title", text: "Performance"
    assert_select ".console-dl-term", text: "Referrals (30d)"
    assert_select ".console-dl-term", text: "Referrals (365d)"
    assert_select ".console-dl-term", text: "Approval rate"
    assert_select ".console-dl-term", text: "Commission earned"
  end

  # --- Onboarding ------------------------------------------------------------------

  test "onboarding checklist has five steps gated on accreditation and go-live" do
    @broker.update_columns(accreditation_ref: nil, status: Broker.statuses[:pending], active: false)
    onboarding = Console::PartnerOnboarding.for(@broker)

    assert_equal 5, onboarding.steps.size
    assert_equal %i[accreditation agreement lender_access commission live], onboarding.steps.map(&:key)
    assert_not onboarding.steps.find { |s| s.key == :accreditation }.done
    assert_not onboarding.steps.find { |s| s.key == :live }.done

    @broker.update_columns(accreditation_ref: "MFAA 12345", status: Broker.statuses[:active])
    refreshed = Console::PartnerOnboarding.for(@broker)
    assert refreshed.steps.find { |s| s.key == :accreditation }.done
    assert refreshed.steps.find { |s| s.key == :live }.done
  end

  test "suspended broker reads Suspended on the checklist" do
    @broker.update_columns(status: Broker.statuses[:suspended], active: false)
    assert_equal "Suspended", Console::PartnerOnboarding.for(@broker).progress_label
  end

  # --- Index -----------------------------------------------------------------------

  test "index filters by status and shows status badges" do
    @broker.update_columns(status: Broker.statuses[:suspended], active: false)

    get console_brokers_path(status: "suspended")
    assert_select "a", text: @broker.name
    assert_select ".console-badge", text: "Suspended"

    get console_brokers_path(status: "pending")
    assert_select "a", { text: @broker.name, count: 0 }
  end
end
