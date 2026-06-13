class WebhookDelivery < ApplicationRecord
  belongs_to :webhook

  # Enums for delivery status
  enum :delivery_status, {
    pending: 0,
    processing: 1,
    delivered: 2,
    failed: 3
  }

  # Validations
  validates :webhook_id, presence: true
  validates :event, presence: true
  validates :payload, presence: true

  scope :delivered, -> { where(delivery_status: :delivered) }
  scope :failed, -> { where(delivery_status: :failed) }
  scope :pending, -> { where(delivery_status: [ :pending, :processing ]) }
  scope :retryable, -> { where(delivery_status: :failed).where("retry_count < ?", 3).where("failed_at < ?", 1.hour.ago) }

  # Mark as successfully delivered
  def mark_delivered(response_code, response_body = nil)
    update(
      delivery_status: :delivered,
      response_code: response_code,
      response_body: response_body,
      delivered_at: Time.current
    )
  end

  # Mark as failed and increment retry count
  def mark_failed(response_code = nil, response_body = nil)
    update(
      delivery_status: :failed,
      response_code: response_code,
      response_body: response_body,
      failed_at: Time.current,
      retry_count: (retry_count || 0) + 1
    )
  end
end
