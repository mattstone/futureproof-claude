require 'test_helper'

class DistributionDedupTest < ActiveSupport::TestCase
  setup do
    @application = applications(:mortgage_application)
    @application.update!(
      status: :accepted,
      equity_investment_amount: 100000,
      lender: lenders(:futureproof)
    )
  end

  test "should not create duplicate distributions for same month" do
    service = PaymentProcessingService.new(@application, 2024, 3)
    
    # First call should create distribution
    distribution1 = service.process_payment
    assert_not_nil distribution1
    assert_equal 3, distribution1.payment_period_month
    assert_equal 2024, distribution1.payment_period_year
    assert_equal Date.new(2024, 3, 1), distribution1.distribution_date
    
    # Second call should return existing distribution, not create new one
    distribution2 = service.process_payment
    assert_equal distribution1.id, distribution2.id
    
    # Should only have one distribution for this period
    assert_equal 1, @application.distributions.for_period(2024, 3).count
  end

  test "should create distributions for different months" do
    service_march = PaymentProcessingService.new(@application, 2024, 3)
    service_april = PaymentProcessingService.new(@application, 2024, 4)
    
    # Create March distribution
    dist_march = service_march.process_payment
    assert_equal 3, dist_march.payment_period_month
    assert_equal Date.new(2024, 3, 1), dist_march.distribution_date
    
    # Create April distribution
    dist_april = service_april.process_payment
    assert_equal 4, dist_april.payment_period_month
    assert_equal Date.new(2024, 4, 1), dist_april.distribution_date
    
    # Should have two different distributions
    refute_equal dist_march.id, dist_april.id
    assert_equal 1, @application.distributions.for_period(2024, 3).count
    assert_equal 1, @application.distributions.for_period(2024, 4).count
  end

  test "distribution date should match payment period" do
    service = PaymentProcessingService.new(@application, 2024, 5)
    distribution = service.process_payment
    
    # distribution_date should be first of payment period month, not next month
    assert_equal Date.new(2024, 5, 1), distribution.distribution_date
    assert_equal 5, distribution.payment_period_month
    assert_equal 2024, distribution.payment_period_year
  end
end