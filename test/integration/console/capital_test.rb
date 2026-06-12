require "test_helper"

class Console::CapitalTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
    @funder = wholesale_funders(:one)
    @pool = @funder.funder_pools.first || FunderPool.create!(wholesale_funder: @funder, name: "Test Pool", amount: 1_000_000, allocated: 250_000)
  end

  test "funder show renders facility headroom and legacy documents" do
    get console_wholesale_funder_path(@funder)

    assert_response :success
    assert_select ".console-card-title", text: "Facility"
    assert_select ".console-dl-term", text: "Unpooled headroom"
    assert_select ".console-card-title", text: "Contract documents"
  end

  test "legacy funding document renders sanitized" do
    document = wholesale_funder_contracts(:legacy_funding_doc)
    get console_wholesale_funder_funding_document_path(@funder, document)

    assert_response :success
    assert_match "Legacy AU funding terms", response.body
    assert_match "Document text on file", response.body
  end

  test "pool top-up changes capacity and writes the audit trail" do
    old_amount = @pool.amount.to_f

    assert_difference -> { AuditLog.where(action: "pool_capacity_changed").count }, 1 do
      post top_up_console_wholesale_funder_funder_pool_path(@funder, @pool),
           params: { amount_delta: 500_000, reason: "Facility increase Q3" }
    end

    assert_equal old_amount + 500_000, @pool.reload.amount.to_f
    log = AuditLog.where(action: "pool_capacity_changed").last
    assert_equal "Facility increase Q3", log.reason
  end

  test "capacity cannot drop below the allocated amount" do
    @pool.update_columns(amount: 1_000_000, allocated: 800_000)

    assert_no_difference -> { AuditLog.count } do
      post top_up_console_wholesale_funder_funder_pool_path(@funder, @pool),
           params: { amount_delta: -500_000, reason: "too far" }
    end

    assert_equal 1_000_000, @pool.reload.amount.to_f
    assert_match(/already allocated/, flash[:alert])
  end

  test "zero adjustment is refused" do
    post top_up_console_wholesale_funder_funder_pool_path(@funder, @pool),
         params: { amount_delta: 0, reason: "noop" }
    assert_match(/non-zero/, flash[:alert])
  end
end
