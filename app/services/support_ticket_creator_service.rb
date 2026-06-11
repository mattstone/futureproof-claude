class SupportTicketCreatorService
  # Processes parsed email data into support tickets
  # Handles: new ticket creation, reply matching, customer identification, attachments

  TICKET_NUMBER_PATTERN = /\[FP-(\d+)\]/

  def initialize(graph_service: nil)
    @graph_service = graph_service
  end

  def process_email(email_data)
    # Skip if already processed (dedup by message_id)
    return if email_data[:message_id].present? &&
              SupportTicketMessage.exists?(microsoft_graph_message_id: email_data[:message_id])

    # Strip subject prefix if present
    subject = clean_subject(email_data[:subject])

    # Check if this is a reply to an existing ticket
    existing_ticket = find_existing_ticket(subject)

    if existing_ticket
      add_reply_to_ticket(existing_ticket, email_data)
    else
      create_new_ticket(email_data, subject)
    end
  end

  private

  def clean_subject(subject)
    return "" if subject.blank?

    cleaned = subject.strip

    # Remove the configured filter prefix (e.g., "test:")
    prefix = Rails.application.credentials.dig(:microsoft_graph, :subject_filter_prefix).presence
    if prefix && cleaned.downcase.start_with?(prefix.downcase)
      cleaned = cleaned[prefix.length..].strip
    end

    # Remove Re:/Fwd: prefixes
    cleaned = cleaned.sub(/\A(Re|Fwd|FW):\s*/i, "").strip

    cleaned
  end

  def find_existing_ticket(subject)
    # Look for ticket number pattern [FP-00001] in subject
    match = subject.match(TICKET_NUMBER_PATTERN)
    return nil unless match

    ticket_number = "FP-#{match[1]}"
    SupportTicket.find_by(ticket_number: ticket_number)
  end

  def create_new_ticket(email_data, subject)
    # Match sender to existing user
    user = match_user(email_data[:sender_email])
    application = match_application(user)

    ticket = SupportTicket.create!(
      ticket_number: "TEMP-#{SecureRandom.hex(4)}", # replaced by after_create callback
      subject: subject.presence || "(No subject)",
      sender_email: email_data[:sender_email],
      sender_name: email_data[:sender_name],
      user: user,
      application: application,
      source: "email",
      microsoft_graph_message_id: email_data[:message_id],
      microsoft_graph_conversation_id: email_data[:conversation_id],
      priority: detect_priority(email_data[:body_text]),
      category: detect_category(subject, email_data[:body_text])
    )

    # Create the first message
    message = ticket.messages.create!(
      sender_type: "customer",
      sender_email: email_data[:sender_email],
      sender_name: email_data[:sender_name],
      body_text: email_data[:body_text],
      body_html: email_data[:body_html],
      microsoft_graph_message_id: email_data[:message_id]
    )

    # Attach files
    attach_files(message, email_data) if email_data[:has_attachments]

    # Send confirmation email
    SupportMailer.ticket_confirmation(ticket).deliver_later

    Rails.logger.info "[SupportTicket] Created #{ticket.ticket_number} from #{email_data[:sender_email]} — #{ticket.contact_type}"

    ticket
  end

  def add_reply_to_ticket(ticket, email_data)
    message = ticket.messages.create!(
      sender_type: "customer",
      sender_email: email_data[:sender_email],
      sender_name: email_data[:sender_name],
      body_text: email_data[:body_text],
      body_html: email_data[:body_html],
      microsoft_graph_message_id: email_data[:message_id]
    )

    # Attach files
    attach_files(message, email_data) if email_data[:has_attachments]

    # Reopen ticket if it was waiting on customer
    if ticket.status.in?(%w[waiting_on_customer resolved])
      ticket.update!(status: "open")
    end

    Rails.logger.info "[SupportTicket] Added reply to #{ticket.ticket_number} from #{email_data[:sender_email]}"

    message
  end

  def match_user(email)
    return nil if email.blank?
    User.find_by("LOWER(email) = ?", email.downcase)
  end

  def match_application(user)
    return nil unless user

    # If user has exactly one active (non-closed) application, link it
    active_apps = user.applications.where.not(status: "closed")
    active_apps.count == 1 ? active_apps.first : nil
  end

  def attach_files(message, email_data)
    return unless @graph_service && email_data[:message_id]

    attachments = @graph_service.fetch_attachments(email_data[:message_id])
    attachments.each do |attachment|
      io = StringIO.new(attachment[:content])
      message.attachments.attach(
        io: io,
        filename: attachment[:filename],
        content_type: attachment[:content_type]
      )
    end
  rescue => e
    Rails.logger.error "[SupportTicket] Failed to attach files for #{email_data[:message_id]}: #{e.message}"
  end

  def detect_priority(body_text)
    return "normal" if body_text.blank?

    text = body_text.downcase
    return "urgent" if text.match?(/urgent|asap|immediately|critical|emergency/)
    return "high" if text.match?(/complain|formal|legal|lawyer|missing payment|not received/)
    "normal"
  end

  def detect_category(subject, body_text)
    combined = "#{subject} #{body_text}".downcase

    return "complaint" if combined.match?(/complain|formal complaint|dispute|dissatisfied/)
    return "payment" if combined.match?(/payment|annuity.*late|not received|missing.*payment/)
    return "application" if combined.match?(/application|applied|status update|valuation/)
    return "technical" if combined.match?(/bug|error|calculator|website|login|can't access/)
    "general"
  end
end
