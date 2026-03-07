require "test_helper"

class BorrowerPortalTest < ActionDispatch::IntegrationTest
  test "borrower portal controller exists" do
    assert defined?(BorrowerPortalController)
  end

  test "borrower portal has required actions" do
    controller = BorrowerPortalController.new
    assert controller.respond_to?(:dashboard)
    assert controller.respond_to?(:annuity_schedule)
    assert controller.respond_to?(:loan_details)
    assert controller.respond_to?(:property_details)
    assert controller.respond_to?(:documents)
  end

  test "borrower portal routes are defined" do
    routes = Rails.application.routes.routes
    route_specs = routes.map { |r| r.path.spec.to_s }
    
    # Check that borrower portal routes exist (they may have slightly different format)
    assert route_specs.any? { |spec| spec.include?("borrower_portal") }
    assert route_specs.any? { |spec| spec.include?("loan_activation") }
  end
end
