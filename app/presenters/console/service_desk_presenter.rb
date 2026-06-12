# Data for the customer Service desk page — ported verbatim from the legacy
# admin customer_service controller so the operational numbers don't drift.
class Console::ServiceDeskPresenter
  STAGES = %w[user_details property_details income_and_loan_options submitted processing].freeze
  STAGE_LABELS = {
    "user_details" => "User details",
    "property_details" => "Property details",
    "income_and_loan_options" => "Income & loan",
    "submitted" => "Submitted",
    "processing" => "Processing"
  }.freeze
  BUCKETS = [
    { key: "0-7d",   label: "0–7 days",   color: "#16a34a", max_age_days: 7 },
    { key: "7-30d",  label: "7–30 days",  color: "#2563eb", max_age_days: 30 },
    { key: "30-60d", label: "30–60 days", color: "#f59e0b", max_age_days: 60 },
    { key: "60d+",   label: "60+ days",   color: "#dc2626", max_age_days: nil }
  ].freeze

  def health_snapshot
    borrower_total_30d = BorrowerMessage.by_borrower.where("created_at >= ?", 30.days.ago).count
    awaiting = BorrowerMessage.by_borrower.where(read_at: nil).where("created_at < ?", 24.hours.ago).count

    {
      open_conversations: ChatConversation.where(status: "active").count,
      awaiting_reply_count: awaiting,
      awaiting_reply_pct: borrower_total_30d.positive? ? (awaiting.to_f / borrower_total_30d * 100).round(1) : 0,
      escalations_this_week: ChatConversation.where(status: "escalated").where("updated_at >= ?", 1.week.ago).count
    }
  end

  def pipeline_aging
    apps_grouped = Application.where(status: STAGES).order(:status).group_by(&:status)

    rows = STAGES.map do |stage|
      apps = apps_grouped[stage] || []
      bucket_counts = BUCKETS.map do |bucket|
        count =
          if bucket[:max_age_days]
            apps.count { |a| age_days(a) <= bucket[:max_age_days] && (bucket[:key] == "0-7d" || age_days(a) > previous_max(bucket)) }
          else
            apps.count { |a| age_days(a) > 60 }
          end
        { bucket: bucket[:key], label: bucket[:label], color: bucket[:color], count: count }
      end
      { stage: STAGE_LABELS[stage], total: apps.size, buckets: bucket_counts }
    end

    { rows: rows, buckets: BUCKETS.map { |b| b.slice(:key, :label, :color) } }
  end

  def unanswered_threads
    app_ids = BorrowerMessage.by_borrower.where(read_at: nil).where("created_at < ?", 24.hours.ago)
                             .pluck(:application_id).uniq
    return [] if app_ids.empty?

    Application.where(id: app_ids).includes(:user).limit(25).filter_map do |app|
      last = BorrowerMessage.where(application_id: app.id).order(created_at: :desc).first
      next unless last && last.sender_type == "borrower"

      {
        application: app,
        last_message_at: last.created_at,
        age_hours: ((Time.current - last.created_at) / 3600.0).round(0),
        message_preview: last.message.to_s.truncate(120)
      }
    end
  end

  def stalled_applications
    Application.where(status: "processing").where("updated_at < ?", 7.days.ago).order(:updated_at).limit(25)
  end

  def escalated_conversations
    ChatConversation.where(status: "escalated").includes(:user, :chat_agent).order(updated_at: :desc).limit(25)
  end

  def urgent_tickets
    SupportTicket.unresolved
                 .order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END"), updated_at: :desc)
                 .limit(25)
  end

  private

  def age_days(app)
    (Date.today - app.updated_at.to_date).to_i
  end

  def previous_max(bucket)
    idx = BUCKETS.index(bucket)
    return 0 if idx.zero?

    BUCKETS[idx - 1][:max_age_days] || 0
  end
end
