require "test_helper"

class Admin::LenderWholesaleFunders::TogglePoolTurboStreamTest < ActionView::TestCase
  setup do
    @lender = lenders(:one)
    @funder_pool = funder_pools(:one)
    @relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    @success = true
    @message = "#{@funder_pool.name} activated"
  end

  test "should render turbo stream for successful toggle" do
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    # Should contain turbo-stream elements
    assert_includes rendered, "<turbo-stream"
    assert_includes rendered, 'action="replace"'
    assert_includes rendered, "pool-toggle-#{@funder_pool.id}"
    
    # Should contain the updated button
    assert_includes rendered, "pool-toggle-btn active"
    assert_includes rendered, "Active"
    
    # Should contain flash message
    assert_includes rendered, "alert alert-success"
    assert_includes rendered, @message
  end

  test "should render correct button state for inactive relationship" do
    @relationship.update!(active: false)
    @message = "#{@funder_pool.name} deactivated"
    
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    # Should show inactive button
    assert_includes rendered, "pool-toggle-btn inactive"
    assert_includes rendered, "Inactive"
    assert_includes rendered, @message
  end

  test "should render error message for failed toggle" do
    @success = false
    @message = "Failed to update pool status"
    
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    # Should not contain button replacement for failed action
    assert_not_includes rendered, 'action="replace"'
    
    # Should contain error message
    assert_includes rendered, "alert alert-error"
    assert_includes rendered, @message
  end

  test "should include auto-hide script for temporary notices" do
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    # Should include JavaScript for auto-hiding notices
    assert_includes rendered, "<script>"
    assert_includes rendered, "setTimeout"
    assert_includes rendered, "temp-notice"
    assert_includes rendered, "3000"
  end

  test "should generate correct form action in button" do
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    expected_path = "/admin/lenders/#{@lender.id}/wholesale_funders/toggle_pool"
    assert_includes rendered, expected_path
    assert_includes rendered, "funder_pool_id"
    assert_includes rendered, @funder_pool.id.to_s
  end

  test "should include turbo stream data attributes" do
    rendered = render(
      template: "admin/lender_wholesale_funders/toggle_pool.turbo_stream.erb",
      locals: {
        lender: @lender,
        funder_pool: @funder_pool,
        relationship: @relationship,
        success: @success,
        message: @message
      }
    )
    
    assert_includes rendered, 'data-turbo-stream="true"'
    assert_includes rendered, 'local="false"'
    assert_includes rendered, 'method="post"'
  end
end