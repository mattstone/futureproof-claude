class AiAgent < ApplicationRecord
  has_many :application_messages, dependent: :nullify
  
  validates :name, presence: true, uniqueness: true
  validates :agent_type, presence: true, inclusion: { in: %w[applications backoffice investment] }
  validates :avatar_filename, presence: true
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(agent_type: type) }
  
  # Get the appropriate agent for a given message type or context
  def self.for_application_context
    active.by_type('applications').first
  end
  
  def self.for_backoffice_context
    active.by_type('backoffice').first
  end
  
  def self.for_investment_context
    active.by_type('investment').first
  end
  
  # Get agent by type with fallback to first active agent
  def self.for_type(agent_type)
    active.by_type(agent_type).first || active.first
  end
  
  def avatar_path
    "ai-agents/#{avatar_filename}"
  end
  
  def asset_avatar_path
    begin
      ActionController::Base.helpers.asset_path("ai-agents/#{avatar_filename}")
    rescue => e
      # Return a fallback path if asset is not found
      "/assets/ai-agents/#{avatar_filename}"
    end
  end
  
  def display_name
    "#{name} AI Assistant"
  end
  
  def role_description
    case agent_type
    when 'applications'
      'Application Processing Specialist'
    when 'backoffice'
      'Back Office Operations Assistant'
    when 'investment'
      'Investment Advisory Specialist'
    else
      'AI Assistant'
    end
  end
  
  def default_greeting
    case greeting_style
    when 'formal'
      "Hello! I'm #{name}, your #{role_description.downcase}. How can I assist you today?"
    when 'friendly'
      "Hi there! #{name} here, ready to help with your #{agent_type} needs. What can I do for you?"
    when 'professional'
      "Good day! This is #{name} from our #{agent_type} team. I'm here to help with your inquiry."
    else
      "Hello! I'm #{name}, here to assist you with your #{agent_type}-related questions."
    end
  end
  
  # Determine the best agent for a given application context
  def self.suggest_for_application(application)
    # Logic to suggest appropriate agent based on application status or context
    case application.status.to_s
    when 'created', 'under_review', 'additional_info_required'
      for_application_context
    when 'approved', 'settlement', 'active'
      for_backoffice_context  
    else
      for_application_context # Default to applications agent
    end
  end
end