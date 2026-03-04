class ChatMessage < ApplicationRecord
  belongs_to :chat_conversation

  validates :role, presence: true, inclusion: { in: %w[user agent system] }
  validates :content, presence: true

  scope :by_role, ->(role) { where(role: role) }
  scope :chronological, -> { order(created_at: :asc) }

  after_create :touch_conversation

  private

  def touch_conversation
    chat_conversation.touch
  end
end
