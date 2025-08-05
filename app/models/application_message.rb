class ApplicationMessage < ApplicationRecord
  belongs_to :application
  belongs_to :sender, polymorphic: true
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
    
    update!(status: 'sent', sent_at: Time.current)
    
    # Send email notification if it's from admin to customer
    if from_admin?
      ApplicationMailer.message_notification(self).deliver_now
    end
    
    true
  rescue => e
    Rails.logger.error "Failed to send message #{id}: #{e.message}"
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
  
  # Convert markup content to HTML
  def content_html
    markup_to_html(content)
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
  
  # Get sender display name
  def sender_name
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
  
  # Get count of unread customer messages for this application
  def self.unread_customer_messages_count(application)
    customer_messages.where(application: application).unread.count
  end
  
  private
  
  # Convert simple markup to HTML (similar to terms markup system)
  def markup_to_html(text)
    return '' if text.blank?
    
    html = text.dup
    
    # Convert line breaks to HTML
    html = html.gsub(/\r\n|\r|\n/, "<br>")
    
    # Convert **bold** to <strong>
    html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    
    # Convert *italic* to <em>
    html = html.gsub(/\*(.+?)\*/, '<em>\1</em>')
    
    # Convert simple bullet points
    html = html.gsub(/^- (.+)$/, '<li>\1</li>')
    html = html.gsub(/(<li>.*<\/li>)/, '<ul>\1</ul>')
    
    # Wrap in paragraph if no other block elements
    unless html.include?('<ul>') || html.include?('<li>')
      html = "<p>#{html}</p>"
    end
    
    html.html_safe
  end
end