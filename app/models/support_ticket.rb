class SupportTicket < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :application, optional: true
  has_many :messages, class_name: "SupportTicketMessage", dependent: :destroy

  STATUSES = %w[open in_progress waiting_on_customer resolved closed].freeze
  PRIORITIES = %w[low normal high urgent].freeze
  CATEGORIES = %w[general application payment technical complaint].freeze

  validates :subject, presence: true
  validates :sender_email, presence: true
  validates :ticket_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :category, inclusion: { in: CATEGORIES }

  after_create :set_ticket_number

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_priority, ->(priority) { where(priority: priority) if priority.present? }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_contact_type, ->(type) {
    case type
    when "customer" then where.not(user_id: nil)
    when "contact" then where(user_id: nil)
    end
  }
  scope :unresolved, -> { where.not(status: %w[resolved closed]) }
  scope :recent_first, -> { order(updated_at: :desc) }
  scope :search, ->(query) {
    if query.present?
      where("subject ILIKE :q OR sender_email ILIKE :q OR sender_name ILIKE :q OR ticket_number ILIKE :q",
            q: "%#{sanitize_sql_like(query)}%")
    end
  }

  def existing_customer?
    user_id.present?
  end

  def contact_type
    existing_customer? ? "Customer" : "New Contact"
  end

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def resolved?
    status == "resolved"
  end

  def last_message_at
    messages.maximum(:created_at) || created_at
  end

  def message_count
    messages.where.not(sender_type: "ai_draft").count
  end

  private

  def set_ticket_number
    update_column(:ticket_number, "FP-#{id.to_s.rjust(5, '0')}")
  end
end
