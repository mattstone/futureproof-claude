class BrokerCommission < ApplicationRecord
  belongs_to :broker
  belongs_to :application

  STATUSES = ["earned", "paid", "pending"].freeze

  validates :commission_amount, presence: true, numericality: { greater_than: 0 }
  validates :commission_rate, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :earned_date, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :broker_id, :application_id, presence: true
  validates :application_id, uniqueness: { message: "can only have one commission per application" }

  scope :earned, -> { where(status: "earned") }
  scope :paid, -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :unpaid, -> { where(status: ["earned", "pending"]) }
  scope :for_broker, ->(broker) { where(broker_id: broker.id) }
  scope :for_period, ->(start_date, end_date) { where(earned_date: start_date..end_date) }

  def mark_as_paid!
    update(status: "paid", paid_date: Time.current)
  end

  def mark_as_earned!
    update(status: "earned")
  end

  def unpaid?
    ["earned", "pending"].include?(status)
  end

  def paid?
    status == "paid"
  end
end
