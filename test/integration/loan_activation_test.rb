require "test_helper"

class LoanActivationTest < ActionDispatch::IntegrationTest
  test "loan activation controller exists" do
    assert defined?(LoanActivationController)
  end

  test "loan activation has required actions" do
    controller = LoanActivationController.new
    assert controller.respond_to?(:show)
    assert controller.respond_to?(:activate)
  end

  test "application model has activated status" do
    assert_includes Application.statuses.keys, "activated"
  end
end
