class AdminOperationsMetricsService
  STATUS_LABELS = {
    "created" => "Not Started",
    "user_details" => "User Info",
    "property_details" => "Property Info",
    "income_and_loan_options" => "Income & Loan",
    "submitted" => "Submitted",
    "processing" => "Processing",
    "accepted" => "Accepted",
    "rejected" => "Rejected"
  }.freeze

  def call
    {
      applications: application_metrics,
      conversion: conversion_metrics,
      support: support_metrics,
      pain_points: pain_points,
      trends: trends,
      kpis: operational_kpis
    }
  end

  def application_metrics
    {
      total: Application.count,
      by_status: Application.group(:status).count.transform_keys { |k| STATUS_LABELS[k] || k.humanize },
      oldest_pending: oldest_pending_application,
      new_this_week: Application.where("created_at >= ?", 1.week.ago).count,
      stalled_applications: Application.where(status: "processing").where("updated_at < ?", 3.days.ago).count,
      submitted_count: Application.where(status: "submitted").count,
      accepted_count: Application.where(status: "accepted").count,
      rejected_count: Application.where(status: "rejected").count,
      acceptance_rate: acceptance_rate
    }
  end

  def conversion_metrics
    total_apps = Application.count
    apps_with_contracts = Application.where.not(contract: nil).count
    conversion_rate = total_apps.positive? ? ((apps_with_contracts.to_f / total_apps) * 100).round(1) : 0

    this_month_apps = Application.where("created_at >= ?", Date.today.beginning_of_month).count
    this_month_contracts = Contract.real.where("created_at >= ?", Date.today.beginning_of_month).count
    last_month_apps = Application.where("created_at >= ?", 1.month.ago.beginning_of_month)
                                 .where("created_at < ?", Date.today.beginning_of_month).count
    last_month_contracts = Contract.real.where("created_at >= ?", 1.month.ago.beginning_of_month)
                                   .where("created_at < ?", Date.today.beginning_of_month).count

    mom_change = last_month_contracts.positive? ? (((this_month_contracts - last_month_contracts).to_f / last_month_contracts) * 100).round(1) : 0

    {
      total_applications: total_apps,
      applications_with_contracts: apps_with_contracts,
      conversion_rate: conversion_rate,
      this_month: month_summary(this_month_apps, this_month_contracts),
      last_month: month_summary(last_month_apps, last_month_contracts),
      mom_trend: mom_change,
      mom_direction: trend_direction(mom_change)
    }
  end

  def support_metrics
    {
      applications_needing_attention: Application.where(status: %w[user_details property_details income_and_loan_options])
                                                 .where("updated_at < ?", 5.days.ago).count,
      rejected_applications: Application.where(status: "rejected").count,
      rejected_this_month: Application.where(status: "rejected")
                                      .where("created_at >= ?", Date.today.beginning_of_month).count,
      contracts_at_risk: Contract.real.where(status: :investment_at_risk).count,
      at_risk_total_value: Contract.real.where(status: :investment_at_risk).sum(:allocated_amount),
      contracts_in_holiday: Contract.real.where(status: :in_holiday).count,
      contracts_completed: Contract.real.where(status: :complete).count,
      completed_this_month: Contract.real.where(status: :complete)
                                    .where("created_at >= ?", Date.today.beginning_of_month).count,
      issues_outstanding: Contract.real.where(status: %i[investment_at_risk in_holiday]).count,
      solutions_delivered: Contract.real.where(status: %i[ok complete]).count
    }
  end

  def pain_points
    points = []
    points << stalled_processing_pain
    points << high_rejection_pain
    points << at_risk_pain
    points << low_conversion_pain
    points << paused_contracts_pain
    points << pipeline_decline_pain
    points.compact!
    points << healthy_pain if points.empty?
    points.sort_by { |p| { critical: 0, warning: 1, info: 2, success: 3 }[p[:severity]] }
  end

  def trends
    {
      applications_monthly: monthly_counts(Application.all),
      contracts_monthly: monthly_counts(Contract.real.all),
      conversion_trend: monthly_conversion_trend,
      rejection_trend: monthly_rejection_trend
    }
  end

  def operational_kpis
    {
      avg_processing_days: average_processing_time,
      approval_rate: acceptance_rate,
      conversion_rate: overall_conversion_rate,
      at_risk_percentage: at_risk_percentage,
      app_growth_mom: mom_growth(Application.all),
      contract_growth_mom: mom_growth(Contract.real.all)
    }
  end

  private

  def oldest_pending_application
    app = Application.where(status: "processing").order(:updated_at).first
    return nil unless app

    {
      id: app.id,
      age_days: (Date.today - app.updated_at.to_date).to_i,
      updated: app.updated_at
    }
  end

  def acceptance_rate
    submitted = Application.where(status: %w[submitted processing accepted rejected]).count
    accepted = Application.where(status: "accepted").count
    submitted.positive? ? ((accepted.to_f / submitted) * 100).round(1) : 0
  end

  def overall_conversion_rate
    total = Application.count
    with_contracts = Application.where.not(contract: nil).count
    total.positive? ? ((with_contracts.to_f / total) * 100).round(1) : 0
  end

  def at_risk_percentage
    total_allocated = Contract.real.sum(:allocated_amount)
    at_risk_value = Contract.real.where(status: :investment_at_risk).sum(:allocated_amount)
    total_allocated.positive? ? ((at_risk_value.to_f / total_allocated) * 100).round(2) : 0
  end

  def average_processing_time
    accepted = Application.where(status: "accepted").where.not(created_at: nil, updated_at: nil)
    return 0 if accepted.empty?

    total_days = accepted.sum { |app| (app.updated_at.to_date - app.created_at.to_date).to_i }
    (total_days.to_f / accepted.count).round(1)
  end

  def mom_growth(scope)
    this_month = scope.where("created_at >= ?", Date.today.beginning_of_month).count
    last_month = scope.where("created_at >= ?", 1.month.ago.beginning_of_month)
                      .where("created_at < ?", Date.today.beginning_of_month).count
    last_month.positive? ? (((this_month - last_month).to_f / last_month) * 100).round(1) : 0
  end

  def month_summary(apps, contracts)
    {
      applications: apps,
      contracts: contracts,
      conversion_rate: apps.positive? ? ((contracts.to_f / apps) * 100).round(1) : 0
    }
  end

  def trend_direction(change)
    return "up" if change.positive?
    return "down" if change.negative?
    "flat"
  end

  def monthly_counts(scope)
    each_month_short(12) do |month_start, month_end|
      scope.where("created_at BETWEEN ? AND ?", month_start, month_end).count
    end
  end

  def monthly_conversion_trend
    each_month_short(12) do |month_start, month_end|
      apps = Application.where("created_at BETWEEN ? AND ?", month_start, month_end).count
      contracts = Contract.real.where("created_at BETWEEN ? AND ?", month_start, month_end).count
      apps.positive? ? ((contracts.to_f / apps) * 100).round(1) : 0
    end
  end

  def monthly_rejection_trend
    each_month_short(12) do |month_start, month_end|
      submitted = Application.where(status: %w[submitted processing accepted rejected])
                             .where("created_at BETWEEN ? AND ?", month_start, month_end).count
      rejected = Application.where(status: "rejected")
                            .where("created_at BETWEEN ? AND ?", month_start, month_end).count
      submitted.positive? ? ((rejected.to_f / submitted) * 100).round(1) : 0
    end
  end

  def each_month_short(months)
    data = {}
    months.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      data[month_start.strftime("%b")] = yield(month_start, month_end)
    end
    data.reverse_each.to_h
  end

  def stalled_processing_pain
    stalled = Application.where(status: "processing").where("updated_at < ?", 7.days.ago).count
    return nil if stalled.zero?

    {
      severity: :critical,
      category: "Processing Bottleneck",
      description: "#{stalled} applications stuck in processing for >7 days",
      impact: "Delayed approvals, customer frustration",
      action: "Review processing queue and clear blockages"
    }
  end

  def high_rejection_pain
    submitted = Application.where(status: %w[submitted processing accepted rejected]).count
    return nil if submitted.zero?

    rate = (Application.where(status: "rejected").count.to_f / submitted * 100).round(1)
    return nil if rate <= 15

    {
      severity: :warning,
      category: "High Rejection Rate",
      description: "#{rate}% of submitted applications are rejected",
      impact: "Low conversion rate, wasted effort on unsuitable applications",
      action: "Analyze rejection reasons and improve pre-qualification"
    }
  end

  def at_risk_pain
    count = Contract.real.where(status: :investment_at_risk).count
    return nil if count.zero?

    value = Contract.real.where(status: :investment_at_risk).sum(:allocated_amount)
    {
      severity: :critical,
      category: "Investment Shortfall",
      description: "#{count} contracts with investment at risk ($#{(value / 1_000_000).round(1)}M exposure)",
      impact: "Potential insurance claims at maturity, funder confidence damage",
      action: "Review investment health and hedging; escalate to investment manager"
    }
  end

  def low_conversion_pain
    rate = overall_conversion_rate
    return nil if rate >= 50

    {
      severity: :warning,
      category: "Low Conversion Rate",
      description: "Only #{rate}% of applications convert to contracts",
      impact: "Inefficient pipeline, low capital deployment",
      action: "Analyze drop-off points and improve approval process"
    }
  end

  def paused_contracts_pain
    count = Contract.real.where(status: :in_holiday).count
    return nil if count <= 5

    {
      severity: :info,
      category: "Paused Contracts",
      description: "#{count} contracts temporarily paused",
      impact: "Revenue gap, unclear activation timeline",
      action: "Create reactivation plan for paused contracts"
    }
  end

  def pipeline_decline_pain
    this_week = Application.where("created_at >= ?", 1.week.ago).count
    last_week = Application.where("created_at >= ?", 2.weeks.ago).where("created_at < ?", 1.week.ago).count
    return nil unless last_week.positive? && this_week < last_week * 0.8

    {
      severity: :warning,
      category: "Pipeline Decline",
      description: "New applications down #{((1 - this_week.to_f / last_week) * 100).round(0)}% week-over-week",
      impact: "Future revenue at risk",
      action: "Increase marketing/broker engagement"
    }
  end

  def healthy_pain
    {
      severity: :success,
      category: "Operations Healthy",
      description: "No critical issues detected",
      impact: "All systems operating normally",
      action: "Maintain current pace"
    }
  end
end
