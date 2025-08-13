class Contract < ApplicationRecord
  belongs_to :application
  has_many :contract_messages, dependent: :destroy
  
  enum :status, {
    awaiting_funding: 0,
    awaiting_investment: 1,
    ok: 2,
    in_holiday: 3,
    in_arrears: 4,
    complete: 5
  }, prefix: true, default: :awaiting_funding
  
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true
  
  validate :end_date_after_start_date
  
  # Display methods
  def status_display
    status.humanize
  end

  # Messaging methods
  def has_unread_customer_messages?
    contract_messages.customer_messages.unread.exists?
  end

  def unread_customer_messages_count
    contract_messages.customer_messages.unread.count
  end

  def latest_customer_message
    contract_messages.customer_messages.sent.order(:created_at).last
  end

  def message_threads
    contract_messages.thread_messages.includes(:replies, :sender).order(created_at: :desc)
  end
  
  private
  
  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
