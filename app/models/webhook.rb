class Webhook < ApplicationRecord
  belongs_to :lender
  has_many :webhook_deliveries, dependent: :destroy

  # Enums for event types
  enum :event, {
    application_created: 0,
    application_submitted: 1,
    application_approved: 2,
    application_rejected: 3,
    distribution_created: 4,
    distribution_processed: 5,
    distribution_failed: 6,
    contract_signed: 7,
    contract_expired: 8
  }

  # Validations
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(['http', 'https']), message: "must be a valid HTTP(S) URL" }
  validates :event, presence: true, inclusion: { in: events.keys }
  validates :secret, presence: true, length: { minimum: 20 }
  validates :lender_id, presence: true

  # Generate secure secret if not provided
  before_validation :generate_secret, if: -> { secret.blank? }

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { where(event: event) }

  def deliver(payload)
    WebhookService.new(self).deliver(payload)
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.urlsafe_base64(32)
  end
end
