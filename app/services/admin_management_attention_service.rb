class AdminManagementAttentionService
  Signal = Struct.new(
    :severity, :category, :headline, :detail, :drill_down_path, :metric,
    keyword_init: true
  )

  SEVERITY_ORDER = { critical: 0, warning: 1, info: 2, success: 3 }.freeze

  def call
    signals = [
      unanswered_borrower_messages,
      stalled_applications,
      escalated_conversations_open,
      unresolved_support_tickets,
      pool_utilisation,
      investment_underperformance,
      agent_failure_rate,
      cross_jurisdiction_audit_events,
      application_volume_drop
    ].compact

    signals.sort_by { |s| SEVERITY_ORDER[s.severity] || 99 }
  end

  def unanswered_borrower_messages
    return nil unless table_exists?(BorrowerMessage)

    borrower_total = BorrowerMessage.by_borrower.where("created_at >= ?", 30.days.ago).count
    return nil if borrower_total.zero?

    unanswered = BorrowerMessage.by_borrower
                                .where(read_at: nil)
                                .where("created_at < ?", 24.hours.ago)
                                .count
    pct = (unanswered.to_f / borrower_total * 100).round(1)
    severity = if pct > 25 then :critical
    elsif pct > 10 then :warning
    else
                 return nil
    end

    Signal.new(
      severity: severity,
      category: "Customer service",
      headline: "#{pct}% of borrower messages awaiting reply > 24h",
      detail: "#{unanswered} of #{borrower_total} messages from borrowers in the last 30 days have no reply within 24h.",
      drill_down_path: "/admin/customer_service",
      metric: pct
    )
  end

  def stalled_applications
    count = Application.where(status: "processing").where("updated_at < ?", 7.days.ago).count
    return nil if count <= 5

    severity = count > 15 ? :critical : :warning
    Signal.new(
      severity: severity,
      category: "Pipeline",
      headline: "#{count} applications stalled in processing > 7 days",
      detail: "Applications have not advanced in over a week. Review processing queue and clear blockers.",
      drill_down_path: "/admin/customer_service",
      metric: count
    )
  end

  def escalated_conversations_open
    count = ChatConversation.where(status: "escalated").count
    return nil if count <= 3

    severity = count > 10 ? :critical : :warning
    Signal.new(
      severity: severity,
      category: "Customer service",
      headline: "#{count} chat conversations escalated and not yet resolved",
      detail: "Customers asked to speak to a human and the conversation has not been closed.",
      drill_down_path: "/admin/customer_service",
      metric: count
    )
  end

  def unresolved_support_tickets
    return nil unless table_exists?(SupportTicket)

    high_count = SupportTicket.unresolved.where(priority: %w[high urgent]).count
    return nil if high_count.zero?

    severity = high_count > 5 ? :critical : :warning
    Signal.new(
      severity: severity,
      category: "Customer service",
      headline: "#{high_count} unresolved high-priority support tickets",
      detail: "High or urgent priority support tickets are open and awaiting resolution.",
      drill_down_path: "/admin/support_tickets",
      metric: high_count
    )
  end

  def pool_utilisation
    capacity = FunderPool.sum(:amount).to_f
    return nil unless capacity.positive?

    allocated = FunderPool.sum(:allocated).to_f
    pct = (allocated / capacity * 100).round(1)
    severity = if pct > 95 then :critical
    elsif pct > 90 then :warning
    else
                 return nil
    end

    Signal.new(
      severity: severity,
      category: "Funding",
      headline: "Funder pool utilisation at #{pct}%",
      detail: "Capital headroom is shrinking. Review wholesale funder commitments and pool allocation.",
      drill_down_path: "/admin/lenders/scorecard",
      metric: pct
    )
  end

  def investment_underperformance
    health = AdminRiskMetricsService.new.portfolio_health
    pct = health[:holiday_pct].to_f
    return nil if pct.zero?

    thresholds = EpmModelConfig.risk_thresholds
    severity = if pct > thresholds[:holiday_rate_critical] * 100 then :critical
    elsif pct > thresholds[:holiday_rate_warning] * 100 then :warning
    else
                 return nil
    end

    Signal.new(
      severity: severity,
      category: "Investment health",
      headline: "#{pct}% of AUM on payment holiday (investment underperforming)",
      detail: "#{health[:holiday_contracts]} contracts paused — investment returns insufficient to support guaranteed income payments.",
      drill_down_path: "/admin/cohorts",
      metric: pct
    )
  end

  def agent_failure_rate
    total = AgentAction.where("created_at >= ?", 7.days.ago).count
    return nil if total.zero?

    failed = AgentAction.where("created_at >= ?", 7.days.ago).where(status: "failed").count
    pct = (failed.to_f / total * 100).round(1)
    severity = if pct > 15 then :critical
    elsif pct > 5 then :warning
    else
                 return nil
    end

    Signal.new(
      severity: severity,
      category: "AI",
      headline: "Agent failure rate at #{pct}% (last 7 days)",
      detail: "#{failed} of #{total} agent actions failed in the last 7 days.",
      drill_down_path: "/admin/agent_dashboard",
      metric: pct
    )
  end

  def cross_jurisdiction_audit_events
    return nil unless table_exists?(AuditLog)

    count = AuditLog.where(action: "cross_jurisdiction_access").where("created_at >= ?", 7.days.ago).count
    return nil if count.zero?

    severity = count > 5 ? :warning : :info
    Signal.new(
      severity: severity,
      category: "Compliance",
      headline: "#{count} cross-jurisdiction access events in the last 7 days",
      detail: "Admins accessed records outside their jurisdiction. Review audit trail.",
      drill_down_path: "/admin/audit_logs",
      metric: count
    )
  end

  def application_volume_drop
    this_week = Application.where("created_at >= ?", 1.week.ago).count
    last_week = Application.where("created_at >= ?", 2.weeks.ago).where("created_at < ?", 1.week.ago).count
    return nil unless last_week >= 5 # avoid noise on tiny baselines
    return nil if this_week >= last_week

    drop_pct = ((1 - this_week.to_f / last_week) * 100).round(0)
    severity = if drop_pct > 40 then :critical
    elsif drop_pct > 20 then :warning
    else
                 return nil
    end

    Signal.new(
      severity: severity,
      category: "Pipeline",
      headline: "New applications down #{drop_pct}% week-over-week",
      detail: "#{this_week} new applications this week vs #{last_week} last week. Review marketing and broker engagement.",
      drill_down_path: "/admin/brokers/scorecard",
      metric: drop_pct
    )
  end

  private

  def table_exists?(model)
    model.table_exists?
  rescue StandardError
    false
  end

  def format_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount, precision: 0)
  end
end
