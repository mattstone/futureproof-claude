class SupportTicketMessage < ApplicationRecord
  belongs_to :support_ticket
  belongs_to :agent_user, class_name: "User", optional: true
  has_many_attached :attachments

  SENDER_TYPES = %w[customer agent system ai_draft].freeze

  validates :sender_type, presence: true, inclusion: { in: SENDER_TYPES }
  validates :body_text, presence: true

  scope :chronological, -> { order(created_at: :asc) }
  scope :visible, -> { where.not(sender_type: "ai_draft") }

  after_create :touch_ticket

  def from_customer?
    sender_type == "customer"
  end

  def from_agent?
    sender_type == "agent"
  end

  def from_system?
    sender_type == "system"
  end

  private

  def touch_ticket
    support_ticket.touch
  end
end
