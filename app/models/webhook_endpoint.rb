class WebhookEndpoint < ApplicationRecord
  belongs_to :user
  has_many :webhook_events, dependent: :destroy

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w(http https)) }
  validates :events, presence: true
  validate :events_are_valid

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event_type) { where("events LIKE ?", "%#{event_type}%") }

  VALID_EVENTS = ['application_created', 'application_approved', 'application_rejected', 'distribution_completed', 'distribution_failed'].freeze

  before_create :generate_secret
  before_create :set_events_default

  def events
    super&.split(',')&.map(&:strip) || []
  end

  def events=(value)
    super(Array(value).join(', '))
  end

  def interested_in?(event_type)
    events.include?(event_type)
  end

  def trigger_event(event_type, payload)
    return unless active? && interested_in?(event_type)
    
    event = webhook_events.create!(
      event_type: event_type,
      payload: payload,
      attempt_count: 0
    )

    WebhookDeliveryJob.perform_later(event.id)
  end

  private

  def generate_secret
    self.secret = SecureRandom.hex(32) if secret.blank?
  end

  def set_events_default
    self.events = VALID_EVENTS if events.blank?
  end

  def events_are_valid
    if events.any? { |e| !VALID_EVENTS.include?(e) }
      errors.add(:events, "contains invalid event types")
    end
  end
end
