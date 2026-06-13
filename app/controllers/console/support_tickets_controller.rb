class Console::SupportTicketsController < Console::ResourceController
  before_action -> { require_capability(:manage_users) }
  before_action :set_ticket, only: [ :show, :update, :reply, :close ]

  resource SupportTicket
  searches "support_tickets.subject", "support_tickets.sender_email",
           "support_tickets.sender_name", "support_tickets.ticket_number"
  sortable updated: "support_tickets.updated_at",
           created: "support_tickets.created_at",
           priority: "support_tickets.priority"
  default_sort :updated, :desc
  filters status: ->(scope, value) { scope.where(status: value) },
          priority: ->(scope, value) { scope.where(priority: value) },
          category: ->(scope, value) { scope.where(category: value) }
  preloads :user

  csv_column("Ticket") { |t| t.ticket_number }
  csv_column("Subject") { |t| t.subject }
  csv_column("From") { |t| t.sender_email }
  csv_column("Status") { |t| t.status }
  csv_column("Priority") { |t| t.priority }
  csv_column("Category") { |t| t.category }
  csv_column("Opened") { |t| t.created_at.iso8601 }
  csv_column("Resolved") { |t| t.resolved_at&.iso8601 }

  def index
    @stats = {
      open: SupportTicket.where(status: "open").count,
      in_progress: SupportTicket.where(status: "in_progress").count,
      waiting: SupportTicket.where(status: "waiting_on_customer").count,
      urgent: SupportTicket.where(priority: "urgent").unresolved.count,
      resolved_today: SupportTicket.where(status: "resolved")
                                   .where("resolved_at >= ?", Time.current.beginning_of_day).count
    }
    super
  end

  def show
    @messages = @ticket.messages.visible.chronological
  end

  def update
    if @ticket.update(ticket_params)
      @ticket.update_column(:resolved_at, Time.current) if @ticket.status == "resolved" && @ticket.resolved_at.nil?
      @ticket.update_column(:closed_at, Time.current) if @ticket.status == "closed" && @ticket.closed_at.nil?
      redirect_to console_support_ticket_path(@ticket), notice: "Ticket updated."
    else
      redirect_to console_support_ticket_path(@ticket), alert: "Could not update ticket."
    end
  end

  def reply
    message = @ticket.messages.build(reply_params)
    message.sender_type = "agent"
    message.sender_name = current_user.display_name
    message.sender_email = current_user.email
    message.agent_user = current_user

    if message.save
      SupportMailer.ticket_reply(message).deliver_later
      @ticket.update(status: "waiting_on_customer") if @ticket.status.in?(%w[open in_progress])
      redirect_to console_support_ticket_path(@ticket), notice: "Reply sent."
    else
      redirect_to console_support_ticket_path(@ticket), alert: "Could not send reply: #{message.errors.full_messages.to_sentence}"
    end
  end

  def close
    @ticket.update(status: "closed", closed_at: Time.current)
    redirect_to console_support_ticket_path(@ticket), notice: "Ticket closed."
  end

  def poll_emails
    EmailIngestionJob.perform_now
    redirect_to console_support_tickets_path, notice: "Email poll complete. Check for new tickets."
  end

  protected

  # Tickets without a user (raw email) are Futureproof-only; lender admins
  # see tickets raised by their own customers.
  def base_scope
    if policy.futureproof?
      SupportTicket.all
    else
      SupportTicket.joins(:user).where(users: { lender: policy.lender })
    end
  end

  private

  def set_ticket
    @ticket = base_scope.find(params[:id])
  end

  def ticket_params
    params.require(:support_ticket).permit(:status, :priority, :category)
  end

  def reply_params
    params.require(:support_ticket_message).permit(:body_text, attachments: [])
  end
end
