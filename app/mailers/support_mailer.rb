class SupportMailer < ActionMailer::Base
  default from: "FutureProof Support <matt.stone@futureprooffinancial.co>"
  layout "mailer"

  def ticket_reply(support_ticket_message)
    @message = support_ticket_message
    @ticket = support_ticket_message.support_ticket
    @agent = support_ticket_message.agent_user

    # Attach any files from the message
    if @message.attachments.attached?
      @message.attachments.each do |attachment|
        attachments[attachment.filename.to_s] = {
          mime_type: attachment.content_type,
          content: attachment.download
        }
      end
    end

    mail(
      to: @ticket.sender_email,
      subject: "Re: [#{@ticket.ticket_number}] #{@ticket.subject}",
      reply_to: "matt.stone@futureprooffinancial.co"
    )
  end

  def ticket_confirmation(support_ticket)
    @ticket = support_ticket

    mail(
      to: @ticket.sender_email,
      subject: "[#{@ticket.ticket_number}] #{@ticket.subject} - We've received your request"
    )
  end
end
