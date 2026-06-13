require "test_helper"

class Console::PortfolioCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @contract = contracts(:active_contract) rescue Contract.first!
  end

  # --- Show depth ----------------------------------------------------------------

  test "contract page shows customer and collateral" do
    get console_contract_path(@contract)
    assert_select ".console-card-title", text: "Customer & collateral"
    assert_select ".console-dl-term", text: "Home value"
    assert_select ".console-dl-term", text: "Borrower age"
    assert_match @contract.application.user.display_name, response.body
  end

  test "economics card shows income, payments and the funding spread" do
    @contract.update_columns(monthly_payment: 1_875.50, total_payments_made: 22_506,
                             investment_return_rate: 9.5, cost_of_capital_rate: 5.2)

    get console_contract_path(@contract)
    assert_select ".console-card-title", text: "Economics"
    assert_match "$1,875.50", response.body
    assert_match "9.5%", response.body
    assert_match "5.2%", response.body
    assert_match "4.3%", response.body # spread
  end

  test "term progress renders between start and end dates" do
    @contract.update_columns(start_date: 5.years.ago.to_date, end_date: 5.years.from_now.to_date)

    get console_contract_path(@contract)
    assert_select "progress.console-progress"
    assert_match(/\d+% of term elapsed/, response.body)
    assert_match(/months to maturity/, response.body)
  end

  test "signed instrument links from the contract" do
    instrument = MortgageContract.first!
    @contract.update_columns(mortgage_contract_id: instrument.id)

    get console_contract_path(@contract)
    assert_select "a[href=?]", console_mortgage_mortgage_contract_path(instrument.mortgage_id, instrument)
  end

  test "demo contracts wear the demo badge" do
    @contract.update_columns(demo: true)

    get console_contract_path(@contract)
    assert_select ".console-badge", text: "Demo data"
  end

  # --- Index depth -----------------------------------------------------------------

  test "index shows end date and unread message indicators" do
    @contract.update_columns(end_date: 10.years.from_now.to_date)
    ContractMessage.create!(contract: @contract, sender_type: "User", sender_id: @contract.application.user_id,
                            message_type: "customer_to_admin", subject: "Question",
                            content: "When is my next payment?", status: "sent", sent_at: Time.current)

    get console_contracts_path
    assert_select "th", text: "End"
    assert_select "th", text: "Messages"
    assert_select ".console-badge", text: /\d+ unread/
  end
end
