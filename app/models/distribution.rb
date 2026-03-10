class Distribution < ApplicationRecord
  belongs_to :application
  belongs_to :mortgage, optional: true
  
  has_one :user, through: :application
  has_one :lender, through: :application
  
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :application, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :distribution_date, presence: true
  validates :status, presence: true
  validates :payment_method, presence: true, if: -> { processing? || completed? }
  
  scope :for_period, ->(year, month) { where(payment_period_year: year, payment_period_month: month) }
  scope :pending_distributions, -> { where(status: :pending) }
  scope :completed_distributions, -> { where(status: :completed) }
  scope :recent, -> { order(distribution_date: :desc) }
  
  def mark_as_processing!(transaction_id = nil)
    update!(status: :processing, transaction_id: transaction_id)
    Rails.logger.info("Distribution #{id} marked as processing (transaction: #{transaction_id})")
  end
  
  def mark_as_completed!(transaction_id = nil)
    transaction do
      update!(status: :completed, transaction_id: transaction_id, processed_at: Time.current)
      Rails.logger.info("Distribution #{id} marked as completed (transaction: #{transaction_id})")
      
      # Log the completion
      if application.user.present?
        Rails.logger.info("EPM distribution of $#{amount.to_i} completed to #{application.user.email} on #{distribution_date}")
      end
      
      # Send email notification
      deliver_payment_notification
      
      # Trigger webhook
      trigger_distribution_webhook
    end
  end
  
  def deliver_payment_notification
    return unless application.user.present?
    
    # Check if notifications are enabled
    if application.user.notification_preference&.payment_email == false
      Rails.logger.info("Payment notification skipped for #{application.user.email} (disabled in preferences)")
      return
    end
    
    BorrowerMailer.payment_distributed(self).deliver_later
    Rails.logger.info("Payment notification email queued for distribution #{id}")
  end
  
  def mark_as_failed!(reason = nil)
    transaction do
      update!(status: :failed, failed_at: Time.current, notes: reason)
      Rails.logger.error("Distribution #{id} failed: #{reason}")
    end
  end
  
  def retry!
    return if status == 'processing'
    update!(status: :pending, failed_at: nil, transaction_id: nil)
    Rails.logger.info("Distribution #{id} retrying EPM distribution")
  end

  def trigger_distribution_webhook
    return unless application.lender_id.present?
    
    payload = {
      event: 'distribution_completed',
      timestamp: processed_at.iso8601,
      distribution: {
        id: id,
        application_id: application_id,
        borrower_name: application.user.full_name,
        borrower_email: application.user.email,
        amount: amount,
        currency: 'AUD',
        transaction_id: transaction_id,
        processed_at: processed_at.iso8601,
        property_address: application.property_address
      }
    }
    
    application.lender.webhook_endpoints.active.for_event('distribution_completed').find_each do |endpoint|
      endpoint.trigger_event('distribution_completed', payload)
    end
  end
end
