# Service object for application messaging operations
# Extracts messaging logic from Admin::ApplicationsController
class ApplicationMessagingService
  attr_reader :application, :admin_user

  def initialize(application, admin_user)
    @application = application
    @admin_user = admin_user
  end

  # Create and send a message to the applicant
  # @param subject [String] Message subject
  # @param content [String] Message content
  # @param ai_agent_id [Integer, nil] Optional AI agent ID
  # @return [ApplicationMessage, nil] Created message or nil on failure
  def create_and_send_message(subject:, content:, ai_agent_id: nil)
    message = application.application_messages.build(
      subject: subject,
      content: content,
      message_type: 'admin_to_customer',
      status: 'draft',
      sender: admin_user,
      ai_agent_id: ai_agent_id
    )

    if message.save
      if message.send_message!
        message
      else
        message.errors.add(:base, 'Failed to send message')
        nil
      end
    else
      nil
    end
  end

  # Get unread messages count for this application
  def unread_messages_count
    application.application_messages
               .where(message_type: 'customer_to_admin', status: 'sent')
               .count
  end

  # Mark all messages as read for this application
  def mark_all_as_read
    application.application_messages
               .where(message_type: 'admin_to_customer', status: 'sent')
               .find_each(&:mark_as_read!)
  end

  # Get message thread
  # @param message_id [Integer] Root message ID
  # @return [Array<ApplicationMessage>] Thread messages
  def get_message_thread(message_id)
    root_message = application.application_messages.find(message_id)
    root_message.thread_messages
  rescue ActiveRecord::RecordNotFound
    []
  end

  # Create a reply to an existing message
  # @param parent_message_id [Integer] Parent message ID
  # @param content [String] Reply content
  # @return [ApplicationMessage, nil] Created reply or nil on failure
  def create_reply(parent_message_id:, content:)
    parent_message = application.application_messages.find(parent_message_id)

    reply = application.application_messages.build(
      subject: "Re: #{parent_message.subject}",
      content: content,
      message_type: 'admin_to_customer',
      status: 'draft',
      sender: admin_user,
      parent_message_id: parent_message_id
    )

    if reply.save && reply.send_message!
      # Mark parent as replied
      parent_message.mark_as_replied!
      reply
    else
      nil
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end