require "test_helper"

class Console::WholesaleFunderManagementTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @funder = wholesale_funders(:one)
  end

  test "funder page shows change history" do
    @funder.current_user = users(:admin_user)
    @funder.update!(name: "#{@funder.name} Holdings")

    get console_wholesale_funder_path(@funder)
    assert_response :success
    assert_select ".console-history-title", text: "Change history"
    assert_select ".console-history-item", minimum: 1
  end

  test "pools list shows allocation bars" do
    FunderPool.create!(wholesale_funder: @funder, name: "Bar Pool", amount: 1_000_000, allocated: 400_000)

    get console_wholesale_funder_path(@funder)
    assert_select ".console-card-title", text: "Pools"
    assert_select "progress.console-progress", minimum: 1
  end

  test "lenders drawing on this funder appear with capacity" do
    lender = lenders(:broker)
    LenderWholesaleFunder.find_or_create_by!(lender: lender, wholesale_funder: @funder) { |r| r.active = true }
    pool = @funder.funder_pools.first || FunderPool.create!(wholesale_funder: @funder, name: "Cap Pool", amount: 2_000_000, allocated: 0)
    LenderFunderPool.find_or_create_by!(lender: lender, funder_pool: pool) { |r| r.active = true }

    get console_wholesale_funder_path(@funder)
    assert_select ".console-card-title", text: "Lenders drawing on this funder"
    assert_select "a", text: lender.name
    assert_match(/capacity/, response.body)
  end

  test "facility card surfaces deployment rate" do
    get console_wholesale_funder_path(@funder)
    assert_select ".console-dl-term", text: "Avg monthly deployment"
  end
end
