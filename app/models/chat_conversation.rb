class ChatConversation < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :chat_agent
  has_many :chat_messages, dependent: :destroy

  validates :status, inclusion: { in: %w[active archived escalated] }

  scope :active, -> { where(status: "active") }
  scope :for_region, ->(region) { where(region: region) }
  scope :recent, -> { order(updated_at: :desc) }

  def last_message
    chat_messages.order(created_at: :desc).first
  end

  def message_count
    chat_messages.count
  end
end
