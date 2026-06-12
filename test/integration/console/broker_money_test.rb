require "test_helper"

class Console::BrokerMoneyTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @broker = brokers(:one)
    @commission = BrokerCommission.create!(
      broker: @broker,
      application: applications(:submitted_application),
      commission_amount: 1250.50,
      commission_rate: 0.25,
      status: "earned",
      earned_date: 2.weeks.ago.to_date
    )
  end

  test "ledger shows totals, filters and the unpaid action" do
    get console_broker_commissions_path

    assert_response :success
    assert_select ".console-stat-label", text: "Unpaid"
    assert_select "td", text: /1,250.50/
    assert_select "form[action=?]", mark_paid_console_broker_commission_path(@commission)

    get console_broker_commissions_path(status: "paid")
    assert_select "td", { text: /1,250.50/, count: 0 }
  end

  test "mark paid stamps the date and audits" do
    assert_difference -> { AuditLog.where(action: "commission_paid").count }, 1 do
      patch mark_paid_console_broker_commission_path(@commission)
    end

    @commission.reload
    assert_equal "paid", @commission.status
    assert_equal Date.current, @commission.paid_date
  end

  test "pay run pays everything unpaid for the broker in one audited action" do
    BrokerCommission.create!(
      broker: @broker, application: applications(:processing_application),
      commission_amount: 800, commission_rate: 0.25, status: "pending", earned_date: 1.week.ago.to_date
    )

    assert_difference -> { AuditLog.where(action: "commission_pay_run").count }, 1 do
      post pay_run_console_broker_commissions_path(broker_id: @broker.id)
    end

    assert_equal 0, BrokerCommission.for_broker(@broker).unpaid.count
    assert_match(/2 commissions/, AuditLog.where(action: "commission_pay_run").last.reason)
  end

  test "broker page shows commission summary and assignment toggles" do
    lender = Lender.where.not(id: @broker.lender_ids).first
    BrokerLender.create!(broker: @broker, lender: lender, active: true)

    get console_broker_path(@broker)

    assert_response :success
    assert_select ".console-card-title", text: "Commissions"
    assert_select ".console-dl-term", text: "Unpaid"
    assert_select "form[action=?]", toggle_lender_console_broker_path(@broker, lender_id: lender.id)
    assert_select "form[action=?]", resend_setup_console_broker_path(@broker)

    patch toggle_lender_console_broker_path(@broker, lender_id: lender.id)
    assert_not BrokerLender.find_by(broker: @broker, lender: lender).active?
  end

  test "resend setup regenerates the token and emails the broker" do
    old_token = @broker.reset_password_token
    assert_enqueued_emails 1 do
      post resend_setup_console_broker_path(@broker)
    end
    assert_not_equal old_token, @broker.reload.reset_password_token
  end

  test "lender admins are denied the ledger" do
    sign_in users(:lender_admin_user)
    get console_broker_commissions_path
    assert_redirected_to console_root_path
  end
end
