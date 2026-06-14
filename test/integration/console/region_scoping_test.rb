require "test_helper"

# The region picker (topbar) flips the session jurisdiction; these prove the
# business indexes actually FILTER on it. Regression for "US is selected but I
# still see AU contracts" — the indexes used to ignore the jurisdiction.
class Console::RegionScopingTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:admin_user) } # Futureproof admin — can switch region

  def switch_to(jurisdiction)
    post console_set_jurisdiction_path, params: { jurisdiction: jurisdiction }
  end

  # --- Acquisition (applications.region holds codes) -------------------------

  test "applications index filters by the selected jurisdiction" do
    au = applications(:submitted_application) # region AU, in active pipeline
    us = applications(:processing_application)
    us.update!(region: "US")

    get console_applications_path # Summary — both
    assert_select "td a", text: "##{au.id}"
    assert_select "td a", text: "##{us.id}"

    switch_to "AU"
    get console_applications_path
    assert_select "td a", text: "##{au.id}"
    assert_select "td a", { text: "##{us.id}", count: 0 }

    switch_to "US"
    get console_applications_path
    assert_select "td a", { text: "##{au.id}", count: 0 }
    assert_select "td a", text: "##{us.id}"
  end

  # --- Contracts (inherit region from their application) ---------------------

  test "contracts index filters by the application's jurisdiction" do
    au_contract = contracts(:active_contract)  # app: submitted_application (AU)
    us_contract = contracts(:funding_contract) # app: second_application
    us_contract.application.update!(region: "US")

    switch_to "AU"
    get console_contracts_path
    assert_select "td a", text: "##{au_contract.id}"
    assert_select "td a", { text: "##{us_contract.id}", count: 0 }

    switch_to "US"
    get console_contracts_path
    assert_select "td a", { text: "##{au_contract.id}", count: 0 }
    assert_select "td a", text: "##{us_contract.id}"
  end

  # --- Alias map bridges full-name columns (country "Australia") to the code -

  test "wholesale funders stored with a full country name match the code picker" do
    au = wholesale_funders(:one) # country: "Australia"
    us = wholesale_funders(:two)
    us.update!(country: "US")

    switch_to "AU"
    get console_wholesale_funders_path
    assert_response :success
    assert_match au.name, response.body         # "Australia" matched by AU
    assert_no_match(/#{Regexp.escape(us.name)}/, response.body)

    switch_to "US"
    get console_wholesale_funders_path
    assert_match us.name, response.body
    assert_no_match(/#{Regexp.escape(au.name)}/, response.body)
  end

  # --- Summary is an explicit passthrough (no filter) ------------------------

  test "Summary shows every jurisdiction" do
    applications(:processing_application).update!(region: "US")

    switch_to "Summary"
    get console_applications_path
    assert_select "td a", text: "##{applications(:submitted_application).id}"
    assert_select "td a", text: "##{applications(:processing_application).id}"
  end
end
