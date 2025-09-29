module Messageable
  extend ActiveSupport::Concern

  included do
    belongs_to :sender, polymorphic: true
    belongs_to :ai_agent, optional: true
    belongs_to :parent_message, class_name: name, optional: true
    has_many :replies, class_name: name, foreign_key: 'parent_message_id', dependent: :destroy
    
    validates :subject, presence: true, length: { maximum: 255 }
    validates :content, presence: true
    validates :message_type, presence: true, inclusion: { in: %w[admin_to_customer customer_to_admin] }
    validates :status, presence: true, inclusion: { in: %w[draft sent read replied] }
    
    scope :recent, -> { order(created_at: :desc) }
    scope :sent, -> { where(status: ['sent', 'read', 'replied']) }
    scope :drafts, -> { where(status: 'draft') }
    scope :unread, -> { where(status: 'sent') }
    scope :admin_messages, -> { where(message_type: 'admin_to_customer') }
    scope :customer_messages, -> { where(message_type: 'customer_to_admin') }
    scope :thread_messages, -> { where(parent_message_id: nil) }
    scope :replies_to, ->(message_id) { where(parent_message_id: message_id) }
  end

  # Message type helpers
  def from_admin?
    message_type == 'admin_to_customer'
  end
  
  def from_customer?
    message_type == 'customer_to_admin'
  end

  # Status helpers
  def sent?
    status.in?(['sent', 'read', 'replied'])
  end
  
  def draft?
    status == 'draft'
  end
  
  def unread?
    status == 'sent'
  end
  
  def read?
    status.in?(['read', 'replied'])
  end

  # Status actions
  def mark_as_read!
    return if read?
    update!(status: 'read', read_at: Time.current)
    clear_unread_message_cache
  end

  def mark_as_replied!
    update!(status: 'replied')
    clear_unread_message_cache
  end

  # Thread helpers
  def thread_messages
    if parent_message_id.present?
      parent_message.thread_messages
    else
      [self] + replies.includes(:sender, :replies).order(:created_at)
    end
  end
  
  def root_message
    parent_message_id.present? ? parent_message.root_message : self
  end

  # Content processing
  def content_html
    processed_content = process_template_variables(content)
    markup_to_html(processed_content)
  end
  
  def processed_subject
    process_template_variables(subject)
  end

  # Formatted timestamps
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  def formatted_sent_at
    sent_at&.strftime("%B %d, %Y at %I:%M %p")
  end
  
  def formatted_read_at
    read_at&.strftime("%B %d, %Y at %I:%M %p")
  end

  # Sender information
  def sender_name
    if ai_agent.present? && from_admin?
      ai_agent.display_name
    else
      case sender
      when User
        if sender.admin?
          "#{sender.display_name} (Admin)"
        else
          sender.display_name
        end
      else
        sender.try(:display_name) || sender.try(:name) || 'Unknown'
      end
    end
  end
  
  def sender_avatar_path
    if ai_agent.present? && from_admin?
      ai_agent.avatar_path
    else
      nil # Could add user avatars later
    end
  end
  
  def sender_role
    if ai_agent.present? && from_admin?
      ai_agent.role_description
    elsif sender.is_a?(User) && sender.admin?
      'Administrator'
    else
      'Customer'
    end
  end
  
  def from_ai_agent?
    ai_agent.present? && from_admin?
  end

  # Public wrapper for template variable processing (useful for testing)
  def process_template_variables_public(text)
    process_template_variables(text)
  end

  private

  # Convert simple markup to HTML (similar to terms markup system)
  def markup_to_html(text)
    return '' if text.blank?
    
    html = text.dup
    
    # Convert **bold** to <strong>
    html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    
    # Convert *italic* to <em>
    html = html.gsub(/\*(.+?)\*/, '<em>\1</em>')
    
    # Convert literal \\n to actual newlines first
    html = html.gsub(/\\n/, "\n")
    
    # Convert simple bullet points (before converting line breaks)
    # Process each line separately to handle multiple bullet points
    lines = html.split(/\n/)
    processed_lines = lines.map do |line|
      if line.strip.start_with?('- ')
        line.gsub(/^- (.+)$/, '<li>\1</li>')
      else
        line
      end
    end
    html = processed_lines.join("\n")
    
    # Wrap consecutive <li> elements in <ul>
    html = html.gsub(/((?:<li>.*<\/li>\n?)+)/m, "<ul>\n\\1</ul>")
    
    # Convert line breaks to HTML
    html = html.gsub(/\r\n|\r|\n/, "<br>")
    
    # Wrap in paragraph if no other block elements
    unless html.include?('<ul>') || html.include?('<li>')
      html = "<p>#{html}</p>"
    end
    
    html.html_safe
  end

  # Process template variables in text content - to be overridden by each model
  def process_template_variables(text)
    return '' if text.blank?
    
    processed_text = text.dup
    
    # Get the user (implementation varies by model)
    user = get_user
    
    # Replace user template variables
    if user
      processed_text.gsub!(/\{\{user\.first_name\}\}/i, user.first_name.to_s)
      processed_text.gsub!(/\{\{user\.last_name\}\}/i, user.last_name.to_s)
      processed_text.gsub!(/\{\{user\.full_name\}\}/i, user.display_name.to_s)
      processed_text.gsub!(/\{\{user\.email\}\}/i, user.email.to_s)
      processed_text.gsub!(/\{\{user\.mobile_number\}\}/i, user.full_mobile_number.to_s) if user.respond_to?(:full_mobile_number)
      processed_text.gsub!(/\{\{user\.country_of_residence\}\}/i, user.country_of_residence.to_s) if user.country_of_residence.present?
    end
    
    # Process specific template variables for the resource type
    processed_text = process_resource_template_variables(processed_text)
    
    processed_text
  end

  # Abstract methods to be implemented by including models
  def get_user
    raise NotImplementedError, "#{self.class} must implement #get_user"
  end

  def process_resource_template_variables(text)
    raise NotImplementedError, "#{self.class} must implement #process_resource_template_variables"
  end

  def send_message!
    raise NotImplementedError, "#{self.class} must implement #send_message!"
  end

  # Clear cached unread message count
  def clear_unread_message_cache
    user_id = get_user&.id
    return unless user_id

    cache_key = "user_#{user_id}_unread_message_count"
    Rails.cache.delete(cache_key)
  end
end