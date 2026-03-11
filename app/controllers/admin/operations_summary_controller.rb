class Admin::OperationsSummaryController < Admin::BaseController
  def index
    # Application pipeline metrics
    @applications = build_application_metrics
    
    # Application to contract conversion
    @conversion = build_conversion_metrics
    
    # Support/issues tracking
    @support = build_support_metrics
    
    # Pain points & blockers
    @pain_points = build_pain_points
    
    # Trend data (historical)
    @trends = build_trends
    
    # KPIs at a glance
    @kpis = build_operational_kpis
  end

  private

  # ============================================================================
  # APPLICATION PIPELINE METRICS
  # ============================================================================
  def build_application_metrics
    statuses = {
      'created' => 'Not Started',
      'user_details' => 'User Info',
      'property_details' => 'Property Info',
      'income_and_loan_options' => 'Income & Loan',
      'submitted' => 'Submitted',
      'processing' => 'Processing',
      'accepted' => 'Accepted',
      'rejected' => 'Rejected'
    }

    {
      total: Application.count,
      by_status: Application.group(:status).count.transform_keys { |k| statuses[k] || k.humanize },
      
      # Application age (how long in current status)
      oldest_pending: Application.where(status: 'processing')
                                  .order(:updated_at)
                                  .first
                                  &.then { |a| { 
                                    id: a.id, 
                                    age_days: ((Date.today - a.updated_at.to_date).to_i),
                                    updated: a.updated_at
                                  }},
      
      # New applications this week
      new_this_week: Application.where('created_at >= ?', 1.week.ago).count,
      
      # Applications pending approval (> 3 days)
      stalled_applications: Application.where(status: 'processing')
                                       .where('updated_at < ?', 3.days.ago)
                                       .count,
      
      # Success rate (submitted → accepted)
      submitted_count: Application.where(status: 'submitted').count,
      accepted_count: Application.where(status: 'accepted').count,
      rejected_count: Application.where(status: 'rejected').count,
      acceptance_rate: calculate_acceptance_rate
    }
  end

  # ============================================================================
  # CONVERSION METRICS (Applications → Contracts)
  # ============================================================================
  def build_conversion_metrics
    total_apps = Application.count
    apps_with_contracts = Application.joins(:contracts).distinct.count
    conversion_rate = total_apps > 0 ? ((apps_with_contracts.to_f / total_apps) * 100).round(1) : 0
    
    # Month-over-month conversion
    this_month_apps = Application.where('created_at >= ?', Date.today.beginning_of_month).count
    this_month_contracts = Contract.where('created_at >= ?', Date.today.beginning_of_month).count
    
    last_month_apps = Application.where('created_at >= ?', 1.month.ago.beginning_of_month)
                                  .where('created_at < ?', Date.today.beginning_of_month)
                                  .count
    last_month_contracts = Contract.where('created_at >= ?', 1.month.ago.beginning_of_month)
                                    .where('created_at < ?', Date.today.beginning_of_month)
                                    .count
    
    mom_change = if last_month_apps > 0
                   (((this_month_contracts - last_month_contracts).to_f / last_month_contracts) * 100).round(1)
                 else
                   0
                 end
    
    {
      total_applications: total_apps,
      applications_with_contracts: apps_with_contracts,
      conversion_rate: conversion_rate,
      
      this_month: {
        applications: this_month_apps,
        contracts: this_month_contracts,
        conversion_rate: this_month_apps > 0 ? ((this_month_contracts.to_f / this_month_apps) * 100).round(1) : 0
      },
      
      last_month: {
        applications: last_month_apps,
        contracts: last_month_contracts,
        conversion_rate: last_month_apps > 0 ? ((last_month_contracts.to_f / last_month_apps) * 100).round(1) : 0
      },
      
      mom_trend: mom_change,
      mom_direction: mom_change > 0 ? 'up' : mom_change < 0 ? 'down' : 'flat'
    }
  end

  # ============================================================================
  # SUPPORT & ISSUES TRACKING
  # ============================================================================
  def build_support_metrics
    {
      # Applications with issues (documents, verification, etc.)
      applications_needing_attention: Application.where(status: %w[user_details property_details income_and_loan_options])
                                                   .where('updated_at < ?', 5.days.ago)
                                                   .count,
      
      # Rejected applications (issues)
      rejected_applications: Application.where(status: 'rejected').count,
      rejected_this_month: Application.where(status: 'rejected')
                                       .where('created_at >= ?', Date.today.beginning_of_month)
                                       .count,
      
      # Contracts in arrears (support needed)
      contracts_in_arrears: Contract.where(status: :in_arrears).count,
      arrears_total_value: Contract.where(status: :in_arrears).sum(:allocated_amount),
      
      # Contracts in holiday (on pause)
      contracts_in_holiday: Contract.where(status: :in_holiday).count,
      
      # Issues resolved (completed contracts)
      contracts_completed: Contract.where(status: :complete).count,
      completed_this_month: Contract.where(status: :complete)
                                     .where('created_at >= ?', Date.today.beginning_of_month)
                                     .count,
      
      # Support ratio (issues vs solutions)
      issues_outstanding: Contract.where(status: [:in_arrears, :in_holiday]).count,
      solutions_delivered: Contract.where(status: [:ok, :complete]).count
    }
  end

  # ============================================================================
  # PAIN POINTS & BLOCKERS
  # ============================================================================
  def build_pain_points
    pain_points = []
    
    # 1. Bottleneck: Applications stuck in processing
    stalled = Application.where(status: 'processing').where('updated_at < ?', 7.days.ago).count
    if stalled > 0
      pain_points << {
        severity: :critical,
        category: 'Processing Bottleneck',
        description: "#{stalled} applications stuck in processing for >7 days",
        impact: 'Delayed approvals, customer frustration',
        action: 'Review processing queue and clear blockages'
      }
    end
    
    # 2. Rejection rate too high
    total_submitted = Application.where(status: %w[submitted processing accepted rejected]).count
    rejections = Application.where(status: 'rejected').count
    if total_submitted > 0
      rejection_rate = (rejections.to_f / total_submitted * 100).round(1)
      if rejection_rate > 15
        pain_points << {
          severity: :warning,
          category: 'High Rejection Rate',
          description: "#{rejection_rate}% of submitted applications are rejected",
          impact: 'Low conversion rate, wasted effort on unsuitable applications',
          action: 'Analyze rejection reasons and improve pre-qualification'
        }
      end
    end
    
    # 3. Contracts in arrears
    arrears_count = Contract.where(status: :in_arrears).count
    if arrears_count > 0
      arrears_value = Contract.where(status: :in_arrears).sum(:allocated_amount)
      pain_points << {
        severity: :critical,
        category: 'Collections Issue',
        description: "#{arrears_count} contracts in arrears ($#{(arrears_value / 1_000_000).round(1)}M at risk)",
        impact: 'Revenue loss, customer relationship damage',
        action: 'Immediate collections action required'
      }
    end
    
    # 4. Slow conversion (apps to contracts)
    conversion_rate = calculate_conversion_rate
    if conversion_rate < 50
      pain_points << {
        severity: :warning,
        category: 'Low Conversion Rate',
        description: "Only #{conversion_rate}% of applications convert to contracts",
        impact: 'Inefficient pipeline, low capital deployment',
        action: 'Analyze drop-off points and improve approval process'
      }
    end
    
    # 5. Contracts in holiday (paused)
    holiday_count = Contract.where(status: :in_holiday).count
    if holiday_count > 5
      pain_points << {
        severity: :info,
        category: 'Paused Contracts',
        description: "#{holiday_count} contracts temporarily paused",
        impact: 'Revenue gap, unclear activation timeline',
        action: 'Create reactivation plan for paused contracts'
      }
    end
    
    # 6. New applications declining
    this_week_apps = Application.where('created_at >= ?', 1.week.ago).count
    last_week_apps = Application.where('created_at >= ?', 2.weeks.ago).where('created_at < ?', 1.week.ago).count
    if last_week_apps > 0 && this_week_apps < last_week_apps * 0.8
      pain_points << {
        severity: :warning,
        category: 'Pipeline Decline',
        description: "New applications down #{((1 - this_week_apps.to_f / last_week_apps) * 100).round(0)}% week-over-week",
        impact: 'Future revenue at risk',
        action: 'Increase marketing/broker engagement'
      }
    end
    
    # Add general status if no critical issues
    if pain_points.empty?
      pain_points << {
        severity: :success,
        category: 'Operations Healthy',
        description: 'No critical issues detected',
        impact: 'All systems operating normally',
        action: 'Maintain current pace'
      }
    end
    
    pain_points.sort_by { |p| { critical: 0, warning: 1, info: 2, success: 3 }[p[:severity]] }
  end

  # ============================================================================
  # TREND DATA
  # ============================================================================
  def build_trends
    {
      # Applications created per month (last 12 months)
      applications_monthly: generate_monthly_applications,
      
      # Contracts created per month
      contracts_monthly: generate_monthly_contracts,
      
      # Conversion rate trend
      conversion_trend: generate_conversion_trend,
      
      # Rejection rate trend
      rejection_trend: generate_rejection_trend
    }
  end

  def generate_monthly_applications
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      count = Application.where('created_at BETWEEN ? AND ?', month_start, month_end).count
      data[month_name] = count
    end
    data.reverse_each.to_h
  end

  def generate_monthly_contracts
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      count = Contract.where('created_at BETWEEN ? AND ?', month_start, month_end).count
      data[month_name] = count
    end
    data.reverse_each.to_h
  end

  def generate_conversion_trend
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      
      apps = Application.where('created_at BETWEEN ? AND ?', month_start, month_end).count
      contracts = Contract.where('created_at BETWEEN ? AND ?', month_start, month_end).count
      
      rate = apps > 0 ? ((contracts.to_f / apps) * 100).round(1) : 0
      data[month_name] = rate
    end
    data.reverse_each.to_h
  end

  def generate_rejection_trend
    data = {}
    12.times do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month
      month_name = month_start.strftime('%b')
      
      submitted = Application.where(status: %w[submitted processing accepted rejected])
                              .where('created_at BETWEEN ? AND ?', month_start, month_end)
                              .count
      rejected = Application.where(status: 'rejected')
                             .where('created_at BETWEEN ? AND ?', month_start, month_end)
                             .count
      
      rate = submitted > 0 ? ((rejected.to_f / submitted) * 100).round(1) : 0
      data[month_name] = rate
    end
    data.reverse_each.to_h
  end

  # ============================================================================
  # KPIs AT A GLANCE
  # ============================================================================
  def build_operational_kpis
    {
      # Processing time
      avg_processing_days: calculate_average_processing_time,
      
      # Approval rate
      approval_rate: calculate_acceptance_rate,
      
      # Conversion rate
      conversion_rate: calculate_conversion_rate,
      
      # Collection health
      arrears_percentage: calculate_arrears_percentage,
      
      # Growth rate (month-over-month)
      app_growth_mom: calculate_app_growth_mom,
      contract_growth_mom: calculate_contract_growth_mom
    }
  end

  # ============================================================================
  # CALCULATION HELPERS
  # ============================================================================

  def calculate_acceptance_rate
    submitted = Application.where(status: %w[submitted processing accepted rejected]).count
    accepted = Application.where(status: 'accepted').count
    submitted > 0 ? ((accepted.to_f / submitted) * 100).round(1) : 0
  end

  def calculate_conversion_rate
    total = Application.count
    with_contracts = Application.joins(:contracts).distinct.count
    total > 0 ? ((with_contracts.to_f / total) * 100).round(1) : 0
  end

  def calculate_arrears_percentage
    total_allocated = Contract.sum(:allocated_amount)
    arrears_value = Contract.where(status: :in_arrears).sum(:allocated_amount)
    total_allocated > 0 ? ((arrears_value.to_f / total_allocated) * 100).round(2) : 0
  end

  def calculate_app_growth_mom
    this_month = Application.where('created_at >= ?', Date.today.beginning_of_month).count
    last_month = Application.where('created_at >= ?', 1.month.ago.beginning_of_month)
                             .where('created_at < ?', Date.today.beginning_of_month)
                             .count
    last_month > 0 ? (((this_month - last_month).to_f / last_month) * 100).round(1) : 0
  end

  def calculate_contract_growth_mom
    this_month = Contract.where('created_at >= ?', Date.today.beginning_of_month).count
    last_month = Contract.where('created_at >= ?', 1.month.ago.beginning_of_month)
                          .where('created_at < ?', Date.today.beginning_of_month)
                          .count
    last_month > 0 ? (((this_month - last_month).to_f / last_month) * 100).round(1) : 0
  end

  def calculate_average_processing_time
    accepted = Application.where(status: 'accepted')
                          .where.not(created_at: nil, updated_at: nil)
    return 0 if accepted.empty?
    
    total_days = accepted.sum { |app| ((app.updated_at.to_date - app.created_at.to_date).to_i) }
    (total_days.to_f / accepted.count).round(1)
  end
end
