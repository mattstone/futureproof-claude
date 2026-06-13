require "test_helper"

class Console::ProductCompletionTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @mortgage = Mortgage.first!
  end

  # --- Usage -----------------------------------------------------------------------

  test "mortgage page shows usage counts and an in-flight warning" do
    application = Application.where.not(id: nil).first!
    application.update_columns(mortgage_id: @mortgage.id, status: Application.statuses[:processing])

    get console_mortgage_path(@mortgage)
    assert_select ".console-card-title", text: "Usage"
    assert_select ".console-dl-term", text: "In flight"
    assert_match "do not retire or reprice", response.body
  end

  test "mortgage with no in-flight applications reads safe to amend" do
    Application.where(mortgage_id: @mortgage.id, status: %i[submitted processing])
               .update_all(status: Application.statuses[:accepted])

    get console_mortgage_path(@mortgage)
    assert_match "safe to amend or retire", response.body
  end

  # --- Financial model ---------------------------------------------------------------

  test "financial model card names the version and flags provisional terms" do
    get console_mortgage_path(@mortgage)
    assert_select ".console-card-title", text: "Financial model"
    assert_match EpmModelConfig.model_version, response.body
    assert_select ".console-badge", text: "Validated", count: EpmModelConfig::VALIDATED_TERMS.size
    assert_select ".console-badge", text: "Provisional",
                  count: EpmModelConfig::ANNUITY_RATES.size - EpmModelConfig::VALIDATED_TERMS.size
    assert_match "do not quote them externally", response.body
  end

  # --- Clause-integrated preview ------------------------------------------------------

  test "mortgage contract preview renders clauses integrated, not raw markup" do
    contract = MortgageContract.first!

    get console_mortgage_mortgage_contract_path(contract.mortgage_id, contract)
    assert_response :success
    assert_match "as customers see it", response.body
  end

  # --- Calculator ------------------------------------------------------------------------

  test "calculator wears the model version badge" do
    get console_calculators_path
    assert_select ".console-badge", text: "Model #{EpmModelConfig.model_version}"
  end
end
