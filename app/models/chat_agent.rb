class ChatAgent < ApplicationRecord
  has_many :chat_conversations, dependent: :destroy

  AGENT_TYPES = %w[onboarding loan_specialist legal support operations].freeze

  validates :name, presence: true
  validates :agent_type, presence: true, inclusion: { in: AGENT_TYPES }
  validates :status, inclusion: { in: %w[active inactive maintenance] }

  scope :active, -> { where(status: "active") }
  scope :by_type, ->(type) { where(agent_type: type) }
  scope :for_region, ->(region) { where("region_support @> ?", [ region ].to_json) }
end
