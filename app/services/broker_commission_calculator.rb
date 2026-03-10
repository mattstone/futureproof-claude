# Service for calculating and managing broker commissions
#
# Handles commission calculation based on:
# - BrokerCommissionRate (per lender/broker configuration)
# - Application approval amount (principal × percentage)
# - Payment trigger (when commission is earned: on_approval, on_funding, on_first_payment)
#
# Commissions are created automatically when applications are approved (via Application#approve!)
# and tracked in BrokerCommission model with status transitions (pending → earned → paid).
#
# Example:
#   calculator = BrokerCommissionCalculator.new(application: app)
#   commission = calculator.calculate_commission_for_approval
#
class BrokerCommissionCalculator
  # Initialize calculator for an application
  #
  # @param application [Application] The application to calculate commission for
  def initialize(application:)
    @application = application
    @broker = application.broker
    @lender = application.lender
  end

  # Calculate and create commission when application is approved
  def calculate_commission_for_approval
    return nil unless @broker && @lender

    commission_rate = find_commission_rate
    return nil unless commission_rate

    calculate_and_create_commission(commission_rate)
  end

  # Get commission for an application (if it exists)
  def get_commission
    BrokerCommission.find_by(application_id: @application.id)
  end

  # Calculate total earned commissions for a broker
  def self.total_earned_commissions(broker, period_start = nil, period_end = nil)
    scope = BrokerCommission.for_broker(broker).earned.paid
    scope = scope.for_period(period_start, period_end) if period_start && period_end
    scope.sum(:commission_amount).to_f
  end

  # Calculate unpaid commissions for a broker
  def self.total_unpaid_commissions(broker, period_start = nil, period_end = nil)
    scope = BrokerCommission.for_broker(broker).unpaid
    scope = scope.for_period(period_start, period_end) if period_start && period_end
    scope.sum(:commission_amount).to_f
  end

  # Get all commissions by period for a broker
  def self.commissions_by_period(broker, period_start, period_end)
    BrokerCommission.for_broker(broker)
                    .for_period(period_start, period_end)
                    .order(earned_date: :desc)
  end

  private

  def find_commission_rate
    BrokerCommissionRate.active
                        .where(broker_id: @broker.id, lender_id: @lender.id)
                        .first
  end

  def calculate_and_create_commission(commission_rate)
    # Only create if not already exists
    return if BrokerCommission.exists?(application_id: @application.id)

    loan_amount = @application.approved_loan_amount.to_f
    commission_amount = commission_rate.calculate_commission(loan_amount)

    commission = BrokerCommission.create!(
      broker_id: @broker.id,
      application_id: @application.id,
      commission_amount: commission_amount,
      commission_rate: commission_rate.commission_percentage,
      earned_date: determine_earned_date(commission_rate),
      status: determine_initial_status(commission_rate)
    )

    # Invalidate broker performance metrics cache (metrics have changed)
    invalidate_broker_metrics_cache if commission && @broker && @lender

    commission
  end

  # Clear cached broker performance metrics
  # Called when commission is created/updated (metrics are no longer accurate)
  def invalidate_broker_metrics_cache
    Rails.cache.delete("broker_metrics:lender:#{@lender.id}")
    Rails.cache.delete("broker_metrics:broker:#{@broker.id}:lender:#{@lender.id}")
  end

  def determine_earned_date(commission_rate)
    case commission_rate.payment_trigger
    when "on_approval"
      Time.current
    when "on_funding"
      # Check if application is already funded (has distributions)
      if @application.distributions.any?
        Time.current
      else
        nil  # Will be set when funding happens
      end
    when "on_first_payment"
      # Will be set when first payment is received
      nil
    end
  end

  def determine_initial_status(commission_rate)
    case commission_rate.payment_trigger
    when "on_approval"
      "earned"
    when "on_funding"
      @application.distributions.any? ? "earned" : "pending"
    when "on_first_payment"
      "pending"
    end
  end
end
