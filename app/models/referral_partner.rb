class ReferralPartner < ApplicationRecord
  include InputSanitization
  has_paper_trail

  belongs_to :lender
  has_many :applications, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :region, presence: true, inclusion: { in: %w[au us nz uk] }
  validates :licence_number, presence: true, uniqueness: { scope: :region }
  validates :commission_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :status, inclusion: { in: %w[active inactive suspended] }

  scope :active, -> { where(status: "active") }
  scope :by_region, ->(region) { where(region: region) }
end
