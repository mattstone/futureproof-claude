require "test_helper"

class MockPaymentServiceTest < ActiveSupport::TestCase
  setup do
    MockPaymentService.set_scenario(:normal)
  end

  test "initiate_settlement returns expected keys" do
    result = MockPaymentService.initiate_settlement(contract_id: 1, amount: 1_000_000, recipient: "test")
    %i[transaction_id status amount recipient].each { |k| assert result.key?(k), "Missing: #{k}" }
    assert result[:transaction_id].start_with?("TXN-")
    assert_equal "pending", result[:status]
  end

  test "initiate_settlement failed scenario" do
    MockPaymentService.set_scenario(:failed)
    result = MockPaymentService.initiate_settlement(contract_id: 1, amount: 1_000_000, recipient: "test")
    assert_equal "failed", result[:status]
  end

  test "initiate_settlement insufficient_funds scenario" do
    MockPaymentService.set_scenario(:insufficient_funds)
    result = MockPaymentService.initiate_settlement(contract_id: 1, amount: 1_000_000, recipient: "test")
    assert_equal "failed", result[:status]
    assert result[:error].include?("Insufficient")
  end

  test "process_monthly_disbursement returns expected keys" do
    result = MockPaymentService.process_monthly_disbursement(contract_id: 1, amount: 2500, recipient: "owner")
    %i[transaction_id status amount recipient_account next_disbursement_date].each { |k| assert result.key?(k), "Missing: #{k}" }
    assert_equal "completed", result[:status]
  end

  test "get_transaction_status returns status" do
    result = MockPaymentService.get_transaction_status("TXN-123456")
    assert result.key?(:status)
    assert result.key?(:transaction_id)
  end

  test "get_payment_history returns array" do
    history = MockPaymentService.get_payment_history(1)
    assert_kind_of Array, history
    assert history.size > 0
    assert history.first.key?(:transaction_id)
  end
end
