class MockMicrosoftGraphService
  # Mock implementation for development/testing without a real Exchange connection
  # Returns sample emails that exercise the full ticket creation pipeline

  def initialize
    @marked_as_read = Set.new
  end

  def fetch_new_emails(limit: 50)
    # Return sample emails that haven't been "read"
    sample_emails.reject { |e| @marked_as_read.include?(e[:message_id]) }.first(limit)
  end

  def fetch_attachments(message_id)
    # Only the third sample email has an attachment
    if message_id == "mock-msg-003"
      [
        {
          filename: "property_valuation.pdf",
          content_type: "application/pdf",
          content: "Mock PDF content for testing",
          size: 1024
        }
      ]
    else
      []
    end
  end

  def mark_as_read(message_id)
    @marked_as_read.add(message_id)
    true
  end

  def send_reply(message_id, body_html)
    Rails.logger.info "[MockGraph] Would send reply to message #{message_id}: #{body_html.truncate(100)}"
    true
  end

  private

  def sample_emails
    # Find a real user to test customer matching
    existing_user = User.where(admin: false).first

    emails = [
      {
        message_id: "mock-msg-001",
        subject: "test: How do I apply for an EPM?",
        sender_email: "newcontact@example.com",
        sender_name: "Jane Doe",
        body_text: "Hi there,\n\nI've heard about the Equity Preservation Mortgage and I'm interested in learning more. I own a home in Sydney worth about $800,000. How do I get started?\n\nThanks,\nJane",
        body_html: "<p>Hi there,</p><p>I've heard about the Equity Preservation Mortgage and I'm interested in learning more. I own a home in Sydney worth about $800,000. How do I get started?</p><p>Thanks,<br>Jane</p>",
        received_at: 5.minutes.ago.iso8601,
        conversation_id: "mock-conv-001",
        has_attachments: false
      },
      {
        message_id: "mock-msg-002",
        subject: "test: My annuity payment is late",
        sender_email: existing_user&.email || "existing@example.com",
        sender_name: existing_user&.display_name || "Existing Customer",
        body_text: "Hello,\n\nMy monthly payment was due on the 1st but I still haven't received it. This is unusual. Can you please check?\n\nRegards",
        body_html: "<p>Hello,</p><p>My monthly payment was due on the 1st but I still haven't received it. This is unusual. Can you please check?</p><p>Regards</p>",
        received_at: 10.minutes.ago.iso8601,
        conversation_id: "mock-conv-002",
        has_attachments: false
      },
      {
        message_id: "mock-msg-003",
        subject: "test: Property valuation query with attachment",
        sender_email: "property.owner@gmail.com",
        sender_name: "Tom Richards",
        body_text: "Hi,\n\nPlease find attached my recent property valuation. I'd like to understand what annuity amount this would support under the EPM.\n\nThe property is a 3-bedroom house in Auckland.\n\nCheers,\nTom",
        body_html: "<p>Hi,</p><p>Please find attached my recent property valuation. I'd like to understand what annuity amount this would support under the EPM.</p><p>The property is a 3-bedroom house in Auckland.</p><p>Cheers,<br>Tom</p>",
        received_at: 15.minutes.ago.iso8601,
        conversation_id: "mock-conv-003",
        has_attachments: true
      }
    ]

    emails
  end
end
