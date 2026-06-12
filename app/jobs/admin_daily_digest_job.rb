# Sends the daily attention digest to FutureProof admins.
# Scheduled via config/recurring.yml (Solid Queue).
class AdminDailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    recommendations = AdminManagementAttentionService.new.call
    counts = {
      open_tickets: SupportTicket.where(status: %w[open in_progress]).count,
      applications_awaiting: Application.where(status: %i[submitted processing]).count,
      open_change_requests: PromptChangeRequest.where.not(state_cache: %w[merged closed]).count
    }

    recipients = User.where(admin: true).joins(:lender)
                     .where(lenders: { lender_type: :futureproof }).pluck(:email)
    return if recipients.empty?

    recipients.each do |email|
      AdminMailer.daily_attention_digest(to: email, recommendations: recommendations, counts: counts).deliver_now
    end
  end
end
