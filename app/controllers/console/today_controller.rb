# The Console home: a work queue, not a wall of charts. What needs a human
# decision right now, with one-click drill-down.
class Console::TodayController < Console::BaseController
  def show
    if policy.futureproof?
      @signals = AdminManagementAttentionService.new.call
      @stats = futureproof_stats
    else
      # The attention service reads platform-wide (pools, agents, audit), so
      # lender admins get their own book's queue and no cross-lender signals.
      @signals = nil
      @stats = lender_stats
    end
  end

  private

  def futureproof_stats
    {
      decisions: Application.where(status: %i[submitted processing]).count,
      documents: ApplicationDocument.where(status: "uploaded").count,
      messages: BorrowerMessage.by_borrower.unread.count,
      tickets: SupportTicket.where(status: %w[open in_progress]).count,
      change_requests: PromptChangeRequest.where.not(state_cache: %w[merged closed]).count
    }
  end

  def lender_stats
    applications = Application.joins(:user).where(users: { lender: policy.lender })

    {
      decisions: applications.where(status: %i[submitted processing]).count,
      documents: ApplicationDocument.where(application: applications, status: "uploaded").count,
      messages: BorrowerMessage.where(application: applications).by_borrower.unread.count
    }
  end
end
