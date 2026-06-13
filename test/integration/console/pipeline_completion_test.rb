require "test_helper"

class Console::PipelineCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @application = applications(:processing_application)
  end

  # --- Approval gating (spec: KYC + AML required before approval) ------------------

  test "approve is refused while compliance is incomplete" do
    @application.kyc_submission&.destroy
    @application.aml_check&.destroy
    @application.application_checklists.each { |item| item.mark_completed!(users(:admin_user)) }

    post approve_console_application_path(@application), params: {
      loan_amount: 500_000, interest_rate: 7.66, term_years: 30, lender_id: lenders(:futureproof).id
    }

    assert_match(/KYC and AML must both be cleared/, flash[:alert])
    assert @application.reload.status_processing?

    get console_application_path(@application)
    assert_match "Approval unlocks once KYC and AML are both cleared", response.body
    assert_select "form[action=?]", approve_console_application_path(@application), count: 0
  end

  # --- Time in stage -----------------------------------------------------------------

  test "header shows days in stage and flags stalled processing" do
    @application.update_columns(updated_at: 10.days.ago)

    get console_application_path(@application)
    assert_match(/10d in stage — stalled/, response.body)
  end

  test "fresh applications are not flagged stalled" do
    @application.update_columns(updated_at: Time.current)

    get console_application_path(@application)
    assert_match(/0d in stage/, response.body)
    assert_no_match(/in stage — stalled/, response.body)
  end

  # --- Broker attribution ----------------------------------------------------------

  test "broker-attributed applications show the broker and commission" do
    broker = brokers(:one)
    @application.update_columns(broker_id: broker.id)
    commission = BrokerCommission.find_or_initialize_by(application: @application)
    commission.update!(broker: broker, commission_amount: 4_500, commission_rate: 0.9,
                       status: "pending", earned_date: Date.current)

    get console_application_path(@application)
    assert_select ".console-dl-term", text: "Broker"
    assert_select "a[href=?]", console_broker_path(broker), text: broker.name
    assert_match "$4,500", response.body
  end

  # --- Funding amount breakdown ------------------------------------------------------

  test "details show the funding amount with its derivation" do
    @application.update_columns(mortgage_id: Mortgage.first!.id) unless @application.mortgage

    get console_application_path(@application)
    assert_select ".console-dl-term", text: "Funding amount"
    assert_match "× LVR", response.body
  end

  # --- Jurisdiction rules -------------------------------------------------------------

  test "details show the jurisdiction rule line" do
    get console_application_path(@application)
    assert_select ".console-dl-term", text: /Jurisdiction rules/
    assert_match(/min age \d+/, response.body)
    assert_match(/LVR ≤ 80%/, response.body)
  end
end
