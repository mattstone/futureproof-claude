module Admin
  class SupportTicketsController < BaseController
    before_action :set_ticket, only: [:show, :update, :reply, :close]

    def index
      @tickets = SupportTicket.recent_first
      @tickets = @tickets.by_status(params[:status])
      @tickets = @tickets.by_priority(params[:priority])
      @tickets = @tickets.by_category(params[:category])
      @tickets = @tickets.by_contact_type(params[:contact_type])
      @tickets = @tickets.search(params[:search])

      # Stats
      @stats = {
        total: SupportTicket.count,
        open: SupportTicket.where(status: "open").count,
        in_progress: SupportTicket.where(status: "in_progress").count,
        waiting: SupportTicket.where(status: "waiting_on_customer").count,
        urgent: SupportTicket.where(priority: "urgent").unresolved.count,
        resolved_today: SupportTicket.where(status: "resolved")
                          .where("resolved_at >= ?", Time.current.beginning_of_day).count
      }
    end

    def show
      @messages = @ticket.messages.visible.chronological
      @new_message = SupportTicketMessage.new
    end

    def update
      if @ticket.update(ticket_params)
        @ticket.update_column(:resolved_at, Time.current) if @ticket.status == "resolved" && @ticket.resolved_at.nil?
        @ticket.update_column(:closed_at, Time.current) if @ticket.status == "closed" && @ticket.closed_at.nil?
        redirect_to admin_support_ticket_path(@ticket), notice: "Ticket updated."
      else
        redirect_to admin_support_ticket_path(@ticket), alert: "Could not update ticket."
      end
    end

    def reply
      message = @ticket.messages.build(reply_params)
      message.sender_type = "agent"
      message.sender_name = current_user.display_name
      message.sender_email = current_user.email
      message.agent_user = current_user

      if message.save
        # Send email to customer
        SupportMailer.ticket_reply(message).deliver_later

        # Update ticket status
        @ticket.update(status: "waiting_on_customer") if @ticket.status.in?(%w[open in_progress])

        redirect_to admin_support_ticket_path(@ticket), notice: "Reply sent."
      else
        redirect_to admin_support_ticket_path(@ticket), alert: "Could not send reply."
      end
    end

    def close
      @ticket.update(status: "closed", closed_at: Time.current)
      redirect_to admin_support_ticket_path(@ticket), notice: "Ticket closed."
    end

    def poll_emails
      EmailIngestionJob.perform_now
      redirect_to admin_support_tickets_path, notice: "Email poll complete. Check for new tickets."
    end

    private

    def set_ticket
      @ticket = SupportTicket.find(params[:id])
    end

    def ticket_params
      params.require(:support_ticket).permit(:status, :priority, :category)
    end

    def reply_params
      params.require(:support_ticket_message).permit(:body_text, attachments: [])
    end
  end
end
