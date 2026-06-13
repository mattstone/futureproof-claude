# Builds every dataset the Analytics page renders — extracted verbatim from
# the legacy admin dashboard controller so the numbers cannot drift during
# the parallel run. Metrics services stay untouched; this only shapes their
# output for the chart components.
class Console::AnalyticsPresenter
  include ActionView::Helpers::NumberHelper

  def initialize(applications_scope:, contracts_scope:, users_scope:)
    @apps = applications_scope
    @contracts = contracts_scope
    @users = users_scope
  end

  def call
    portfolio = AdminPortfolioMetricsService.new(applications_scope: @apps, contracts_scope: @contracts, users_scope: @users)
    financial = AdminFinancialMetricsService.new(applications_scope: @apps, contracts_scope: @contracts).call
    risk = AdminRiskMetricsService.new(applications_scope: @apps, contracts_scope: @contracts).call

    {
      financial_overview: financial_overview(portfolio, financial),
      acquisition_overview: acquisition_overview(portfolio),
      service_overview: service_overview,
      risk_overview: risk_overview(risk),
      trends: trends(portfolio),
      funnel: funnel,
      gauges: gauges(portfolio, risk),
      calendar: calendar,
      geo: geo(portfolio),
      # Breadth restored from the legacy dashboard — every metric the
      # services compute now reaches the page (AN-1).
      portfolio_summary: portfolio.top_line,
      contract_status: portfolio.contract_summary,
      account_balances: portfolio.account_balances,
      capital_deployment: financial[:capital],
      distributions: financial[:distributions],
      concentration: risk[:concentration],
      monitoring: risk[:monitoring],
      model_context: risk[:model]
    }
  end

  private

  def financial_overview(portfolio, financial)
    capital = portfolio.capital_overview
    revenue = financial[:revenue]
    contracts = portfolio.contract_summary

    {
      total_aum: capital[:total_capital_raised],
      capital_deployed: capital[:capital_deployed],
      capital_available: capital[:capital_available],
      wacc: capital[:wacc],
      portfolio_pl: contracts[:portfolio_pl],
      net_margin_annual: revenue[:net_margin_annual]
    }
  end

  def acquisition_overview(portfolio)
    this_month = @apps.where("applications.created_at >= ?", Date.today.beginning_of_month).count
    last_month = @apps.where("applications.created_at >= ?", 1.month.ago.beginning_of_month)
                      .where("applications.created_at < ?", Date.today.beginning_of_month).count

    top_brokers = Application.joins(:broker)
                             .where("applications.created_at >= ?", 90.days.ago)
                             .group("brokers.name")
                             .order("count_all DESC")
                             .limit(3)
                             .count

    regions = portfolio.top_line[:applications_by_region]

    submitted = @apps.where(status: %w[submitted processing accepted rejected]).count
    accepted = @apps.where(status: "accepted").count
    conversion = submitted.positive? ? (accepted.to_f / submitted * 100).round(1) : 0

    {
      applications_this_month: this_month,
      applications_last_month: last_month,
      delta_pct: last_month.positive? ? (((this_month - last_month).to_f / last_month) * 100).round(0) : 0,
      top_brokers: top_brokers,
      regional_split: regions,
      conversion_rate: conversion
    }
  end

  def service_overview
    open_conversations = ChatConversation.where(status: "active").count
    borrower_total_30d = BorrowerMessage.by_borrower.where("created_at >= ?", 30.days.ago).count
    awaiting = BorrowerMessage.by_borrower.where(read_at: nil).where("created_at < ?", 24.hours.ago).count
    awaiting_pct = borrower_total_30d.positive? ? (awaiting.to_f / borrower_total_30d * 100).round(1) : 0
    escalations = ChatConversation.where(status: "escalated").where("updated_at >= ?", 1.week.ago).count
    stalled = Application.where(status: "processing").where("updated_at < ?", 7.days.ago).count

    {
      open_conversations: open_conversations,
      awaiting_reply_count: awaiting,
      awaiting_reply_pct: awaiting_pct,
      escalations_this_week: escalations,
      stalled_applications: stalled
    }
  end

  def risk_overview(risk)
    health = risk[:portfolio_health]
    alerts = risk[:alerts] || []
    total = health[:total_contracts].to_i
    performing = total - health[:holiday_contracts].to_i

    {
      health_score: health[:health_score],
      health_rating: health[:health_rating],
      investment_health_pct: (100 - health[:holiday_pct].to_f).round(1),
      performing_contracts: performing,
      total_contracts: total,
      holiday_pct: health[:holiday_pct],
      alert_count: alerts.count { |a| a[:severity] != :success }
    }
  end

  def geo(portfolio)
    regions = portfolio.top_line
    iso_for = { "AU" => "036", "US" => "840", "NZ" => "554", "UK" => "826" }
    iso_for.map do |region, iso|
      {
        region: region,
        iso: iso,
        applications: regions[:applications_by_region][region].to_i,
        capital: regions[:capital_by_region][region].to_f
      }
    end
  end

  def calendar
    from = 364.days.ago.to_date
    counts = @apps.where("applications.created_at >= ?", from.beginning_of_day)
                  .group("DATE(applications.created_at)").count
                  .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
    days = (from..Date.today).map do |date|
      { date: date.iso8601, count: counts[date].to_i, weekday: date.wday }
    end
    { days: days, max: counts.values.max.to_i, total: days.sum { |d| d[:count] } }
  end

  def gauges(portfolio, risk)
    health = risk[:portfolio_health]

    pool_capacity = FunderPool.sum(:amount).to_f
    pool_allocated = FunderPool.sum(:allocated).to_f
    pool_pct = pool_capacity.positive? ? (pool_allocated / pool_capacity * 100).round(1) : 0

    submitted = @apps.where(status: %w[submitted processing accepted rejected]).count
    accepted = @apps.where(status: "accepted").count
    conversion = submitted.positive? ? (accepted.to_f / submitted * 100).round(1) : 0

    [
      {
        label: "Health Score",
        value: health[:health_score],
        max: 100,
        unit: "%",
        detail: health[:health_rating],
        higher_is_better: true,
        warning_at: 75,
        critical_at: 60
      },
      {
        label: "Pool Utilisation",
        value: pool_pct,
        max: 100,
        unit: "%",
        detail: "#{number_to_currency(pool_allocated, precision: 0, unit: '$')} of #{number_to_currency(pool_capacity, precision: 0, unit: '$')}",
        higher_is_better: false,
        warning_at: 90,
        critical_at: 95
      },
      {
        label: "Investment Health",
        value: (100 - health[:holiday_pct].to_f).round(1),
        max: 100,
        unit: "%",
        detail: "#{health[:total_contracts] - health[:holiday_contracts]} of #{health[:total_contracts]} contracts performing",
        higher_is_better: true,
        warning_at: 75,
        critical_at: 60
      },
      {
        label: "Conversion Rate",
        value: conversion,
        max: 100,
        unit: "%",
        detail: "#{accepted} accepted of #{submitted} submitted",
        higher_is_better: true,
        warning_at: 50,
        critical_at: 30
      }
    ]
  end

  def funnel
    stages = %w[created user_details property_details income_and_loan_options submitted processing accepted]
    stage_labels = {
      "created" => "Started",
      "user_details" => "User details",
      "property_details" => "Property details",
      "income_and_loan_options" => "Income & loan",
      "submitted" => "Submitted",
      "processing" => "Processing",
      "accepted" => "Accepted"
    }
    counts = @apps.group(:status).count
    rejected = counts["rejected"].to_i

    ever_reached = stages.each_with_index.map do |_stage, i|
      stages[i..].sum { |s| counts[s].to_i }
    end

    nodes = stages.each_with_index.map { |s, i| { name: stage_labels[s], value: ever_reached[i] } }

    links = []
    stages.each_cons(2).with_index do |(_from, _to), i|
      next if ever_reached[i + 1].zero?
      links << { source: i, target: i + 1, value: ever_reached[i + 1] }
    end

    drop_index = nodes.size
    stages.each_with_index do |stage, i|
      next if i == stages.size - 1
      dropped = ever_reached[i] - ever_reached[i + 1]
      next if dropped <= 0
      nodes << { name: "#{stage_labels[stage]} dropped", value: dropped, drop: true }
      links << { source: i, target: drop_index, value: dropped }
      drop_index += 1
    end

    if rejected.positive?
      nodes << { name: "Rejected", value: rejected, rejected: true }
      links << { source: stages.index("processing"), target: nodes.size - 1, value: rejected }
    end

    { nodes: nodes, links: links, total_started: ever_reached[0] }
  end

  def trends(portfolio)
    {
      applications_monthly: portfolio.growth_data(scope: @apps, months: 12),
      pl_monthly: portfolio.monthly_pl(months: 12),
      fum_monthly: portfolio.monthly_fum(months: 12)
    }
  end
end
