require "test_helper"

class Console::ProductTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @mortgage = mortgages(:interest_only)
  end

  # --- Mortgages ----------------------------------------------------------------

  test "mortgage show lists contract versions with publish/activate controls" do
    get console_mortgage_path(@mortgage)

    assert_response :success
    assert_select ".console-card-title", text: "Contract documents"
    assert_select "form[action=?]", publish_console_mortgage_mortgage_contract_path(@mortgage, mortgage_contracts(:io_draft_contract))
  end

  test "mortgage create and update" do
    post console_mortgages_path, params: { mortgage: { name: "Test Product X", mortgage_type: "interest_only", lvr: 75, status: "active" } }
    mortgage = Mortgage.find_by(name: "Test Product X")
    assert mortgage
    assert_redirected_to console_mortgage_path(mortgage)

    patch console_mortgage_path(mortgage), params: { mortgage: { name: "Test Product X", mortgage_type: "interest_only", lvr: 70, status: "active" } }
    assert_equal 70, mortgage.reload.lvr
  end

  # --- Mortgage contracts -----------------------------------------------------------

  test "new contract version prefills from the latest and publishes" do
    get new_console_mortgage_mortgage_contract_path(@mortgage)
    assert_response :success

    assert_difference -> { @mortgage.mortgage_contracts.count }, 1 do
      post console_mortgage_mortgage_contracts_path(@mortgage), params: {
        mortgage_contract: { title: "Mortgage Contract", content: "## 1. Updated\n\nNew wording." }
      }
    end

    contract = @mortgage.mortgage_contracts.order(:version).last
    assert contract.draft?

    patch publish_console_mortgage_mortgage_contract_path(@mortgage, contract)
    assert_not contract.reload.draft?

    patch activate_console_mortgage_mortgage_contract_path(@mortgage, contract)
    assert contract.reload.is_active?
  end

  test "editing a published contract forks a new draft" do
    contract = mortgage_contracts(:io_active_contract)

    assert_difference -> { @mortgage.mortgage_contracts.count }, 1 do
      patch console_mortgage_mortgage_contract_path(@mortgage, contract), params: {
        mortgage_contract: { title: contract.title, content: "## Changed content" }
      }
    end

    assert_not_equal "## Changed content", contract.reload.content
    assert @mortgage.mortgage_contracts.drafts.where("content LIKE ?", "%Changed content%").exists?
  end

  # --- FAQs ----------------------------------------------------------------------------

  test "faqs index scopes by jurisdiction switcher" do
    get console_faqs_path
    assert_response :success
    assert_select ".console-stat-label", text: "Published"
  end

  test "faq create" do
    assert_difference "Faq.count", 1 do
      post console_faqs_path, params: { faq: { jurisdiction: "AU", question: "What is an EPM?", answer: "An Equity Preservation Mortgage.", published: "1" } }
    end
    assert_redirected_to console_faqs_path
  end

  # --- Calculator --------------------------------------------------------------------------

  test "calculator page renders the full parameter form" do
    get console_calculators_path

    assert_response :success
    assert_select "[data-controller='monte-carlo-calculator']"
    assert_select "input[name='calculator[house_value]']"
    assert_select "form[action=?]", console_calculate_calculators_path
    assert_select "[data-monte-carlo-calculator-target='results']"
  end

  # --- Access ----------------------------------------------------------------------------------

  test "lender admins are denied the product section" do
    sign_in users(:lender_admin_user)
    get console_mortgages_path
    assert_redirected_to console_root_path
    get console_calculators_path
    assert_redirected_to console_root_path
  end
end
