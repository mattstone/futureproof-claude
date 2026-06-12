require "test_helper"

class Console::PartnersTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @lender = lenders(:broker)
  end

  # --- Lenders -----------------------------------------------------------------

  test "lenders index shows summary stats and filters by type" do
    get console_lenders_path
    assert_response :success
    assert_select ".console-stat-label", text: "Capital deployed"
    assert_select "td a", text: lenders(:futureproof).name

    get console_lenders_path(lender_type: "futureproof")
    assert_select "td a", text: lenders(:futureproof).name
    assert_select "td a", { text: @lender.name, count: 0 }
  end

  test "lender show renders relationships, clause and commission sections" do
    get console_lender_path(@lender)

    assert_response :success
    assert_select ".console-card-title", text: "Wholesale funders"
    assert_select ".console-card-title", text: "Funder pools"
    assert_select ".console-card-title", text: "Contract clause"
    assert_select ".console-card-title", text: "Broker commission rates"
  end

  test "scorecard renders capital flow and concentration" do
    get scorecard_console_lenders_path
    assert_response :success
    assert_select "td a", text: lenders(:futureproof).name
    assert_select ".console-stat-label", text: /Herfindahl/
  end

  test "wholesale funder relationship add, toggle and remove" do
    funder = WholesaleFunder.where.not(id: @lender.wholesale_funders.select(:id)).first
    assert funder, "needs an unlinked wholesale funder fixture"

    assert_difference -> { @lender.lender_wholesale_funders.count }, 1 do
      post console_lender_wholesale_funders_path(@lender), params: { wholesale_funder_id: funder.id }
    end
    relationship = @lender.lender_wholesale_funders.order(:created_at).last

    patch toggle_active_console_lender_wholesale_funder_path(@lender, relationship)
    assert_not relationship.reload.active?

    assert_difference -> { @lender.lender_wholesale_funders.count }, -1 do
      delete console_lender_wholesale_funder_path(@lender, relationship)
    end
  end

  test "clause edit and update" do
    get edit_console_lender_clause_path(@lender)
    assert_response :success

    patch console_lender_clause_path(@lender), params: { clause: { content: "Custom wording for this lender." } }
    assert_redirected_to console_lender_path(@lender)
    assert @lender.reload.has_clause?
  end

  test "commission rate create and toggle" do
    broker = Broker.where.not(id: @lender.broker_commission_rates.select(:broker_id)).first
    assert broker, "needs a broker without an existing rate for this lender"

    assert_difference -> { @lender.broker_commission_rates.count }, 1 do
      post console_lender_broker_commission_rates_path(@lender), params: {
        broker_commission_rate: { broker_id: broker.id, commission_percentage: 1.25, payment_trigger: "on_funding" }
      }
    end

    rate = @lender.broker_commission_rates.order(:created_at).last
    patch toggle_active_console_lender_broker_commission_rate_path(@lender, rate)
    assert_not rate.reload.active?
  end

  # --- Wholesale funders & pools ---------------------------------------------------

  test "wholesale funders index shows global stats" do
    get console_wholesale_funders_path
    assert_response :success
    assert_select ".console-stat-label", text: "Total capital"
  end

  test "wholesale funder show lists pools" do
    funder = wholesale_funders(:one)
    get console_wholesale_funder_path(funder)
    assert_response :success
    assert_select ".console-card-title", text: "Pools"
  end

  test "pool create under a funder updates capacity listing" do
    funder = WholesaleFunder.first

    assert_difference -> { funder.funder_pools.count }, 1 do
      post console_wholesale_funder_funder_pools_path(funder), params: {
        funder_pool: { name: "Test Pool 2026", amount: 1_000_000, benchmark_rate: 4.35, margin_rate: 2.0 }
      }
    end
    assert_redirected_to console_wholesale_funder_path(funder)
  end

  test "pools index searches across pool and funder names" do
    pool = FunderPool.first
    get console_funder_pools_path(search: pool.name[0, 6])
    assert_response :success
    assert_select "td a", text: pool.name
  end

  # --- Access ------------------------------------------------------------------------

  test "lender admins are denied the partners section" do
    sign_in users(:lender_admin_user)

    get console_lenders_path
    assert_redirected_to console_root_path

    get console_wholesale_funders_path
    assert_redirected_to console_root_path
  end
end
