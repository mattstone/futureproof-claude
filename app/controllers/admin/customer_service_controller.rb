module Admin
  class CustomerServiceController < Admin::BaseController
    def index
      @health_snapshot = build_health_snapshot
      @priority_inbox = AdminAttentionInboxService.new.call
      @pipeline_aging = build_pipeline_aging
      @unanswered_threads = unanswered_borrower_threads
      @stalled_applications = Application.where(status: 'processing')
                                         .where('updated_at < ?', 7.days.ago)
                                         .order(:updated_at)
                                         .limit(25)
      @escalated_conversations = ChatConversation.where(status: 'escalated')
                                                 .includes(:user, :chat_agent)
                                                 .order(updated_at: :desc)
                                                 .limit(25)
      @open_tickets = SupportTicket.unresolved
                                   .order(Arel.sql("CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END"), updated_at: :desc)
                                   .limit(25)
    end

    private

    def build_pipeline_aging
      stages = %w[user_details property_details income_and_loan_options submitted processing]
      stage_labels = {
        'user_details' => 'User details',
        'property_details' => 'Property details',
        'income_and_loan_options' => 'Income & loan',
        'submitted' => 'Submitted',
        'processing' => 'Processing'
      }
      buckets = [
        { key: '0-7d',   label: '0–7 days',   color: '#16a34a', max_age_days: 7 },
        { key: '7-30d',  label: '7–30 days',  color: '#2563eb', max_age_days: 30 },
        { key: '30-60d', label: '30–60 days', color: '#f59e0b', max_age_days: 60 },
        { key: '60d+',   label: '60+ days',   color: '#dc2626', max_age_days: nil }
      ]

      apps_grouped = Application.where(status: stages).order(:status).group_by(&:status)

      rows = stages.map do |stage|
        apps = apps_grouped[stage] || []
        bucket_counts = buckets.map do |bucket|
          if bucket[:max_age_days]
            count = apps.count { |a| age_days(a) <= bucket[:max_age_days] && (bucket[:key] == '0-7d' || age_days(a) > previous_max(buckets, bucket)) }
          else
            count = apps.count { |a| age_days(a) > 60 }
          end
          { bucket: bucket[:key], label: bucket[:label], color: bucket[:color], count: count }
        end
        { stage: stage_labels[stage], total: apps.size, buckets: bucket_counts }
      end

      { rows: rows, buckets: buckets.map { |b| { key: b[:key], label: b[:label], color: b[:color] } } }
    end

    def age_days(app)
      (Date.today - app.updated_at.to_date).to_i
    end

    def previous_max(buckets, bucket)
      idx = buckets.index(bucket)
      return 0 if idx.zero?
      buckets[idx - 1][:max_age_days] || 0
    end

    def build_health_snapshot
      open_conversations = ChatConversation.where(status: 'active').count
      borrower_total_30d = BorrowerMessage.by_borrower.where('created_at >= ?', 30.days.ago).count
      awaiting = BorrowerMessage.by_borrower.where(read_at: nil).where('created_at < ?', 24.hours.ago).count
      awaiting_pct = borrower_total_30d.positive? ? (awaiting.to_f / borrower_total_30d * 100).round(1) : 0
      escalations_this_week = ChatConversation.where(status: 'escalated').where('updated_at >= ?', 1.week.ago).count

      {
        open_conversations: open_conversations,
        awaiting_reply_count: awaiting,
        awaiting_reply_pct: awaiting_pct,
        avg_response_time_hours: avg_response_time_hours,
        escalations_this_week: escalations_this_week
      }
    end

    def avg_response_time_hours
      replies = BorrowerMessage.by_lender.where('created_at >= ?', 30.days.ago)
      times = replies.find_each.filter_map do |reply|
        prior_borrower_msg = BorrowerMessage.by_borrower
                                            .where(application_id: reply.application_id)
                                            .where('created_at < ?', reply.created_at)
                                            .order(created_at: :desc)
                                            .first
        next unless prior_borrower_msg
        ((reply.created_at - prior_borrower_msg.created_at) / 3600.0).round(1)
      end
      return 0 if times.empty?
      (times.sum / times.size).round(1)
    end

    def unanswered_borrower_threads
      apps = BorrowerMessage.by_borrower.where(read_at: nil).where('created_at < ?', 24.hours.ago)
                            .pluck(:application_id).uniq
      return [] if apps.empty?

      Application.where(id: apps).includes(:user).limit(25).map do |app|
        last = BorrowerMessage.where(application_id: app.id).order(created_at: :desc).first
        next unless last && last.sender_type == 'borrower'
        {
          application: app,
          last_message_at: last.created_at,
          age_hours: ((Time.current - last.created_at) / 3600.0).round(0),
          message_preview: last.message.to_s.truncate(120)
        }
      end.compact.sort_by { |t| -t[:age_hours] }
    end
  end
end
