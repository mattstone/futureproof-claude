class PaymentProcessingService
  # Process monthly distributions for approved applications
  #
  # This service:
  # 1. Calculates monthly payment based on approved loan amount and interest rate
  # 2. Creates a Distribution record with pending status
  # 3. Processes payment through mock payment processor
  # 4. Updates distribution status and transaction ID
  # 5. Logs all activity for compliance
  
  attr_reader :application, :distribution_month, :distribution_year
  
  def initialize(application, year = nil, month = nil)
    @application = application
    @distribution_year = year || Date.current.year
    @distribution_month = month || Date.current.month
  end
  
  def self.process_monthly_distributions(year = nil, month = nil)
    # Process all approved applications for the given month
    year ||= Date.current.year
    month ||= Date.current.month
    
    approved_apps = Application.where(status: :accepted)
    results = {
      success: 0,
      failed: 0,
      skipped: 0,
      distributions: []
    }
    
    approved_apps.find_each do |app|
      service = new(app, year, month)
      
      begin
        distribution = service.process_payment
        results[:distributions] << distribution
        results[:success] += 1
        Rails.logger.info("Processed payment for Application #{app.id}: $#{distribution.amount}")
      rescue => e
        results[:failed] += 1
        Rails.logger.error("Failed to process payment for Application #{app.id}: #{e.message}")
      end
    end
    
    results
  end
  
  def process_payment
    # Don't create duplicate distributions for same month
    existing = application.distributions.for_month(@distribution_year, @distribution_month).first
    return existing if existing.present?
    
    # Calculate payment amount
    monthly_payment = calculate_monthly_payment
    return nil if monthly_payment.zero?
    
    # Determine distribution date (first of next month)
    distribution_date = Date.new(@distribution_year, @distribution_month, 1) + 1.month
    
    # Create distribution record
    distribution = application.distributions.create!(
      amount: monthly_payment,
      lender_margin: calculate_lender_margin(monthly_payment),
      distribution_date: distribution_date,
      status: :pending,
      payment_method: 'ach',  # Default to ACH
      notes: "Automatic monthly EPM distribution for #{Date.new(@distribution_year, @distribution_month, 1).strftime('%B %Y')}"
    )
    
    # Process payment
    process_with_payment_gateway(distribution)
    
    distribution
  end
  
  private
  
  def calculate_monthly_payment
    return 0 if application.status != 'accepted' || application.approved_loan_amount.nil?
    
    # Calculate monthly payment using approved terms
    # Monthly Payment = P * [r(1+r)^n] / [(1+r)^n - 1]
    principal = application.approved_loan_amount.to_f
    annual_rate = application.approved_interest_rate.to_f / 100
    monthly_rate = annual_rate / 12
    num_payments = application.approved_term_years * 12
    
    return principal if monthly_rate.zero?
    
    (principal * (monthly_rate * (1 + monthly_rate) ** num_payments) / ((1 + monthly_rate) ** num_payments - 1)).round(2)
  end
  
  def calculate_lender_margin(payment_amount)
    # Lender takes 1% margin on each distribution
    (payment_amount * 0.01).round(2)
  end
  
  def process_with_payment_gateway(distribution)
    # In production, this would call Stripe/ACH/Wire transfer API
    # For now, mock the payment processor
    
    mock_processor = MockPaymentProcessor.new
    
    begin
      # Mark as processing
      distribution.mark_as_processing!
      
      # Call mock processor
      transaction_id = mock_processor.process_payment(
        amount: distribution.amount,
        recipient_email: application.user.email,  # Use email for mock processor
        description: "Monthly EPM distribution"
      )
      
      # Mark as completed
      distribution.mark_as_completed!(transaction_id)
      
      Rails.logger.info("Payment processed for Distribution #{distribution.id}: Transaction #{transaction_id}")
    rescue => e
      distribution.mark_as_failed!(e.message)
      raise e
    end
  end
  
  class MockPaymentProcessor
    def process_payment(amount:, recipient_email:, description:)
      # Simulate network latency
      sleep 0.1
      
      # Generate mock transaction ID
      transaction_id = "TXN-#{Time.current.to_i}-#{rand(100000..999999)}"
      
      # Log the mock transaction
      Rails.logger.info("Mock Payment Processor: Transferred $#{amount} to #{recipient_email} (#{description}) - TXN: #{transaction_id}")
      
      # In production, this would integrate with real payment gateway (Stripe, ACH, Wire, etc)
      # For MVP, return mock transaction ID
      transaction_id
    end
  end
end
