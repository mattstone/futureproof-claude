require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "mortgage contract renders for AU region" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
  end

  test "AU mortgage contract includes NNEG clause" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "No Negative Equity Guarantee"
    assert_includes response.body, "NNEG Protection"
    assert_includes response.body, "NNEG trigger is activated"
  end

  test "AU mortgage contract includes advised sales acknowledgement" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "Advised Sales Acknowledgement"
    assert_includes response.body, "Right to Sell"
    assert_includes response.body, "Sale Proceeds"
  end

  test "AU mortgage contract includes Centrelink disclosure" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "Centrelink"
    assert_includes response.body, "Age Pension"
    assert_includes response.body, "Assets Test Impact"
    assert_includes response.body, "Deeming"
  end

  test "AU mortgage contract includes NNEG probability and trigger" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "NNEG Probability"
    assert_includes response.body, "NNEG Trigger and Resolution"
    assert_includes response.body, "Pool Coverage insurance"
  end

  test "AU mortgage contract specifies Australian regulatory framework" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "National Consumer Credit Protection Act 2009"
    assert_includes response.body, "ASIC"
    assert_includes response.body, "Australian Credit Licence"
  end

  test "AU mortgage contract includes Australian-specific compliance" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "Privacy Act 1988"
    assert_includes response.body, "Australian Privacy Principles"
    assert_includes response.body, "Anti-Money Laundering and Counter-Terrorism Financing Act 2006"
  end

  test "AU mortgage contract includes Australian Financial Complaints Authority (AFCA)" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "AFCA"
  end

  test "AU mortgage contract specifies minimum age requirement" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "55 years or older"
  end

  test "AU mortgage contract requires Australian residency" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "Australian resident"
  end

  test "AU mortgage contract specifies cooling-off period" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "14 days"
  end

  test "AU mortgage contract includes tax treatment guidance" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "Tax Treatment"
    assert_includes response.body, "capital drawdown"
    assert_includes response.body, "tax-free"
  end

  test "AU mortgage contract includes witness requirements" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "WITNESS"
    assert_includes response.body, "required for this deed"
  end

  test "AU mortgage contract specifies 80% LTV maximum" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "80%"
  end

  test "AU mortgage contract specifies A$500,000 minimum property value" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "A$500,000"
  end

  test "AU mortgage contract describes equity preservation" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "preservation of equity"
    assert_includes response.body, "remains static"
  end

  test "AU mortgage contract renders without errors" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.content_type, 'text/html'
  end

  test "AU mortgage contract is accessible without authentication" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
  end

  test "AU mortgage contract includes signature blocks" do
    get legal_mortgage_contract_path(region: 'au')
    assert_response :success
    assert_includes response.body, "SIGNED by the LENDER"
    assert_includes response.body, "SIGNED by the BORROWER"
  end
end
