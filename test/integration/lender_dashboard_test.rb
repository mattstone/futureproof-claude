require "test_helper"

class LenderDashboardTest < ActionDispatch::IntegrationTest
  test "lender dashboard controller exists" do
    assert defined?(LenderDashboard::LenderDashboardController)
  end

  test "lender dashboard has required actions" do
    controller = LenderDashboard::LenderDashboardController.new
    assert controller.respond_to?(:index)
    assert controller.respond_to?(:applications)
    assert controller.respond_to?(:application_detail)
    assert controller.respond_to?(:payments)
    assert controller.respond_to?(:reports)
    assert controller.respond_to?(:account)
    assert controller.respond_to?(:update_account)
  end

  test "lender dashboard routes are defined" do
    route_specs = Rails.application.routes.routes.map { |r| r.path.spec.to_s }
    assert route_specs.any? { |spec| spec.include?("lender_dashboard") }
  end
end
