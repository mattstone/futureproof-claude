class ApplicationMessage < ApplicationRecord
  # include InputSanitization  # Temporarily disabled for testing
  
  belongs_to :application
  belongs_to :sender, polymorphic: true
  belongs_to :ai_agent, optional: true
  belongs_to :parent_message, class_name: 'ApplicationMessage', optional: true
  has_many :replies, class_name: 'ApplicationMessage', foreign_key: 'parent_message_id', dependent: :destroy
  
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
  
  # Check if message is from admin
  def from_admin?
    message_type == 'admin_to_customer'
  end
  
  # Check if message is from customer
  def from_customer?
    message_type == 'customer_to_admin'
  end
  
  # Check if message has been sent
  def sent?
    status.in?(['sent', 'read', 'replied'])
  end
  
  # Check if message is draft
  def draft?
    status == 'draft'
  end
  
  # Check if message is unread
  def unread?
    status == 'sent'
  end
  
  # Check if message has been read
  def read?
    status.in?(['read', 'replied'])
  end
  
  # Mark message as read
  def mark_as_read!
    return if read?
    update!(status: 'read', read_at: Time.current)
  end
  
  # Mark message as replied
  def mark_as_replied!
    update!(status: 'replied')
  end
  
  # Send the message
  def send_message!
    return false unless draft?
    
    # Send email notification if it's from admin to customer
    if from_admin?
      ApplicationMailer.message_notification(self).deliver_now
    end
    
    # Only mark as sent if email sending succeeded
    update!(status: 'sent', sent_at: Time.current)
    true
  rescue => e
    Rails.logger.error "Failed to send message #{id}: #{e.message}"
    # Keep status as draft if sending failed
    false
  end
  
  # Get all messages in thread (parent + replies)
  def thread_messages
    if parent_message_id.present?
      parent_message.thread_messages
    else
      [self] + replies.includes(:sender, :replies).order(:created_at)
    end
  end
  
  # Get the root message of the thread
  def root_message
    parent_message_id.present? ? parent_message.root_message : self
  end
  
  # Convert markup content to HTML with template variable replacement
  def content_html
    processed_content = process_template_variables(content)
    markup_to_html(processed_content)
  end
  
  # Get processed subject with template variables replaced
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
  
  # Get sender display name - show AI agent if present, otherwise actual sender
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
  
  # Get sender avatar - show AI agent avatar if present
  def sender_avatar_path
    if ai_agent.present? && from_admin?
      ai_agent.avatar_path
    else
      nil # Could add user avatars later
    end
  end
  
  # Get sender role/title
  def sender_role
    if ai_agent.present? && from_admin?
      ai_agent.role_description
    elsif sender.is_a?(User) && sender.admin?
      'Administrator'
    else
      'Customer'
    end
  end
  
  # Check if message appears to be from AI agent
  def from_ai_agent?
    ai_agent.present? && from_admin?
  end
  
  # Get count of unread customer messages for this application
  def self.unread_customer_messages_count(application)
    customer_messages.where(application: application).unread.count
  end
  
  private
  
  # Process template variables in text content
  def process_template_variables(text)
    return '' if text.blank?
    
    processed_text = text.dup
    
    # Get the user from the application
    user = application.user
    
    # Replace user template variables
    if user
      processed_text.gsub!(/\{\{user\.first_name\}\}/i, user.first_name.to_s)
      processed_text.gsub!(/\{\{user\.last_name\}\}/i, user.last_name.to_s)
      processed_text.gsub!(/\{\{user\.full_name\}\}/i, user.display_name.to_s)
      processed_text.gsub!(/\{\{user\.email\}\}/i, user.email.to_s)
      processed_text.gsub!(/\{\{user\.mobile_number\}\}/i, user.full_mobile_number.to_s) if user.respond_to?(:full_mobile_number)
      processed_text.gsub!(/\{\{user\.country_of_residence\}\}/i, user.country_of_residence.to_s) if user.country_of_residence.present?
    end
    
    # Replace application template variables
    if application
      processed_text.gsub!(/\{\{application\.id\}\}/i, application.id.to_s)
      processed_text.gsub!(/\{\{application\.reference_number\}\}/i, application.id.to_s.rjust(6, '0'))
      processed_text.gsub!(/\{\{application\.address\}\}/i, application.address.to_s)
      processed_text.gsub!(/\{\{application\.home_value\}\}/i, application.home_value.to_s)
      processed_text.gsub!(/\{\{application\.formatted_home_value\}\}/i, application.formatted_home_value.to_s) if application.respond_to?(:formatted_home_value)
      processed_text.gsub!(/\{\{application\.existing_mortgage_amount\}\}/i, application.existing_mortgage_amount.to_s) if application.existing_mortgage_amount.present?
      processed_text.gsub!(/\{\{application\.formatted_existing_mortgage_amount\}\}/i, application.formatted_existing_mortgage_amount.to_s) if application.respond_to?(:formatted_existing_mortgage_amount)
      processed_text.gsub!(/\{\{application\.borrower_age\}\}/i, application.borrower_age.to_s) if application.borrower_age.present?
      processed_text.gsub!(/\{\{application\.status\}\}/i, application.status.to_s)
      processed_text.gsub!(/\{\{application\.status_display\}\}/i, application.status.humanize)
      
      # Add loan-related fields if they exist
      if application.respond_to?(:loan_value) && application.loan_value.present?
        processed_text.gsub!(/\{\{application\.loan_value\}\}/i, application.loan_value.to_s)
        processed_text.gsub!(/\{\{application\.formatted_loan_value\}\}/i, application.formatted_loan_value.to_s) if application.respond_to?(:formatted_loan_value)
      end
      
      if application.respond_to?(:loan_term) && application.loan_term.present?
        processed_text.gsub!(/\{\{application\.loan_term\}\}/i, application.loan_term.to_s)
      end
      
      if application.respond_to?(:growth_rate) && application.growth_rate.present?
        processed_text.gsub!(/\{\{application\.growth_rate\}\}/i, application.growth_rate.to_s)
        processed_text.gsub!(/\{\{application\.formatted_growth_rate\}\}/i, application.formatted_growth_rate.to_s) if application.respond_to?(:formatted_growth_rate)
      end
    end
    
    # Replace mortgage template variables if mortgage is associated
    if application&.mortgage
      mortgage = application.mortgage
      processed_text.gsub!(/\{\{mortgage\.name\}\}/i, mortgage.name.to_s)
      processed_text.gsub!(/\{\{mortgage\.lvr\}\}/i, mortgage.lvr.to_s) if mortgage.respond_to?(:lvr)
      processed_text.gsub!(/\{\{mortgage\.interest_rate\}\}/i, '7.45') # Static for now, same as email template
      processed_text.gsub!(/\{\{mortgage\.mortgage_type_display\}\}/i, mortgage.mortgage_type_display.to_s) if mortgage.respond_to?(:mortgage_type_display)
    end
    
    processed_text
  end
  
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
end