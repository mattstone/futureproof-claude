require "test_helper"

class Console::ServicingTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @contract = contracts(:active_contract) # status ok
  end

  test "contract show renders servicing summary and available transitions" do
    Distribution.create!(application: @contract.application, amount: 2500, status: :completed,
                         distribution_date: 1.month.ago.to_date, payment_period_month: 5, payment_period_year: 2026,
                         payment_method: "bank_transfer")

    get console_contract_path(@contract)

    assert_response :success
    assert_select ".console-card-title", text: "Servicing"
    assert_select ".console-card-title", text: "Income payments"
    assert_select ".console-dl-value", text: /2,500/
    assert_select "form[action*=?]", "transition"
  end

  test "holiday cycle: start requires reason, audits, and end restores" do
    patch transition_console_contract_path(@contract, kind: "start_holiday")
    assert_match(/reason is required/, flash[:alert])
    assert @contract.reload.status_ok?

    assert_difference -> { AuditLog.where(action: "contract_start_holiday").count }, 1 do
      patch transition_console_contract_path(@contract, kind: "start_holiday"), params: { reason: "Investment under threshold" }
    end
    assert @contract.reload.status_in_holiday?

    patch transition_console_contract_path(@contract, kind: "end_holiday"), params: { reason: "Recovered above exit threshold" }
    assert @contract.reload.status_ok?
  end

  test "invalid transitions are refused" do
    patch transition_console_contract_path(@contract, kind: "end_holiday"), params: { reason: "not in holiday" }
    assert_match(/isn't available/, flash[:alert])
    assert @contract.reload.status_ok?

    patch transition_console_contract_path(@contract, kind: "nonsense"), params: { reason: "x" }
    assert_match(/isn't available/, flash[:alert])
  end

  test "at-risk flag and restore audit with old->new in notes" do
    patch transition_console_contract_path(@contract, kind: "flag_at_risk"), params: { reason: "Two missed quarters" }
    assert @contract.reload.status_investment_at_risk?
    assert_match "ok -> investment_at_risk", AuditLog.where(action: "contract_flag_at_risk").last.notes

    patch transition_console_contract_path(@contract, kind: "restore"), params: { reason: "Caught up" }
    assert @contract.reload.status_ok?
  end

  test "complete is terminal — no transitions offered" do
    @contract.update_columns(status: Contract.statuses[:complete])
    get console_contract_path(@contract)
    assert_match(/No servicing transitions available/, response.body)
  end
end
