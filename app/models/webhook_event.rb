class WebhookEvent < ApplicationRecord
  belongs_to :webhook_endpoint

  enum :status, { pending: 0, delivered: 1, failed: 2 }, prefix: true

  validates :event_type, :payload, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :failed, -> { where(status: :failed) }
  scope :delivered, -> { where(status: :delivered) }

  def retry!
    return if attempt_count >= 3
    
    update(attempt_count: attempt_count + 1)
    WebhookDeliveryJob.set(wait: (2 ** attempt_count).minutes).perform_later(id)
  end

  def mark_delivered!
    update(status: :delivered, delivered_at: Time.current, error_message: nil)
  end

  def mark_failed!(error = nil)
    update(status: :failed, error_message: error)
    retry! if attempt_count < 3
  end
end
