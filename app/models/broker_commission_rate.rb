class BrokerCommissionRate < ApplicationRecord
  belongs_to :broker
  belongs_to :lender
  has_many :broker_commissions, through: :broker, source: :broker_commissions

  PAYMENT_TRIGGERS = [ "on_approval", "on_funding", "on_first_payment" ].freeze

  validates :commission_percentage, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :payment_trigger, presence: true, inclusion: { in: PAYMENT_TRIGGERS }
  validates :broker_id, uniqueness: { scope: :lender_id, message: "can only have one commission rate per lender" }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :for_lender, ->(lender) { where(lender_id: lender.id) }
  scope :for_broker, ->(broker) { where(broker_id: broker.id) }

  def calculate_commission(loan_amount)
    (loan_amount * commission_percentage / 100).round(2)
  end
end
