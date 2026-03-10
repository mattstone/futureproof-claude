class BorrowerMessage < ApplicationRecord
  belongs_to :application
  belongs_to :user
  belongs_to :lender, optional: true

  enum sender_type: { borrower: "borrower", lender: "lender" }

  validates :message, presence: true, length: { minimum: 1, maximum: 5000 }
  validates :sender_type, presence: true, inclusion: { in: sender_types.keys }

  scope :for_application, ->(application) { where(application_id: application.id) }
  scope :unread, -> { where(read_at: nil) }
  scope :by_borrower, -> { where(sender_type: "borrower") }
  scope :by_lender, -> { where(sender_type: "lender") }

  def from_borrower?
    sender_type == "borrower"
  end

  def from_lender?
    sender_type == "lender"
  end

  def mark_as_read!
    update(read_at: Time.current) if read_at.nil?
  end
end
