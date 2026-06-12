module Admin
  class DashboardController < Admin::BaseController
    include Admin::AdminHelper
    include ActionView::Helpers::NumberHelper

    def index
      apps = jurisdiction_filtered_scope(Application.all, :region)
      contracts = jurisdiction_filtered_contracts(apps)
      portfolio = AdminPortfolioMetricsService.new(applications_scope: apps, contracts_scope: contracts, users_scope: scoped_users)
      financial = AdminFinancialMetricsService.new(applications_scope: apps, contracts_scope: contracts).call
      risk = AdminRiskMetricsService.new(applications_scope: apps, contracts_scope: contracts).call

      @recommendations = AdminManagementAttentionService.new.call

      @financial_overview = build_financial_overview(portfolio, financial)
      @customer_acquisition_overview = build_customer_acquisition_overview(apps, portfolio)
      @customer_service_overview = build_customer_service_overview
      @risk_overview = build_risk_overview(risk)

      @trends = build_trends(portfolio, apps)
      @funnel = build_funnel(apps)
      @gauges = build_gauges(portfolio, risk, apps)
      @calendar = build_calendar(apps)
      @geo = build_geo(portfolio)

      @current_jurisdiction = current_admin_jurisdiction
    end

    private

    def jurisdiction_filtered_contracts(apps)
      app_ids = apps.pluck(:id)
      return Contract.none if app_ids.empty?
      Contract.real.where(application_id: app_ids)
    end

    def build_financial_overview(portfolio, financial)
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

    def build_customer_acquisition_overview(apps, portfolio)
      this_month = apps.where('created_at >= ?', Date.today.beginning_of_month).count
      last_month = apps.where('created_at >= ?', 1.month.ago.beginning_of_month).where('created_at < ?', Date.today.beginning_of_month).count

      top_brokers = Application.joins(:broker)
                               .where('applications.created_at >= ?', 90.days.ago)
                               .group('brokers.name')
                               .order('count_all DESC')
                               .limit(3)
                               .count

      regions = portfolio.top_line[:applications_by_region]

      submitted = apps.where(status: %w[submitted processing accepted rejected]).count
      accepted = apps.where(status: 'accepted').count
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

    def build_customer_service_overview
      open_conversations = ChatConversation.where(status: 'active').count
      borrower_total_30d = BorrowerMessage.by_borrower.where('created_at >= ?', 30.days.ago).count
      awaiting = BorrowerMessage.by_borrower.where(read_at: nil).where('created_at < ?', 24.hours.ago).count
      awaiting_pct = borrower_total_30d.positive? ? (awaiting.to_f / borrower_total_30d * 100).round(1) : 0
      escalations = ChatConversation.where(status: 'escalated').where('updated_at >= ?', 1.week.ago).count
      stalled = Application.where(status: 'processing').where('updated_at < ?', 7.days.ago).count

      {
        open_conversations: open_conversations,
        awaiting_reply_count: awaiting,
        awaiting_reply_pct: awaiting_pct,
        escalations_this_week: escalations,
        stalled_applications: stalled
      }
    end

    def build_risk_overview(risk)
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

    def build_geo(portfolio)
      regions = portfolio.top_line
      iso_for = { 'AU' => '036', 'US' => '840', 'NZ' => '554', 'UK' => '826' }
      iso_for.map do |region, iso|
        {
          region: region,
          iso: iso,
          applications: regions[:applications_by_region][region].to_i,
          capital: regions[:capital_by_region][region].to_f
        }
      end
    end

    def build_calendar(apps)
      from = 364.days.ago.to_date
      counts = apps.where('created_at >= ?', from.beginning_of_day)
                   .group("DATE(created_at)").count
                   .transform_keys { |k| k.is_a?(String) ? Date.parse(k) : k }
      days = (from..Date.today).map do |date|
        { date: date.iso8601, count: counts[date].to_i, weekday: date.wday }
      end
      { days: days, max: counts.values.max.to_i, total: days.sum { |d| d[:count] } }
    end

    def build_gauges(portfolio, risk, apps)
      capital = portfolio.capital_overview
      health = risk[:portfolio_health]

      pool_capacity = FunderPool.sum(:amount).to_f
      pool_allocated = FunderPool.sum(:allocated).to_f
      pool_pct = pool_capacity.positive? ? (pool_allocated / pool_capacity * 100).round(1) : 0

      submitted = apps.where(status: %w[submitted processing accepted rejected]).count
      accepted = apps.where(status: 'accepted').count
      conversion = submitted.positive? ? (accepted.to_f / submitted * 100).round(1) : 0

      [
        {
          label: 'Health Score',
          value: health[:health_score],
          max: 100,
          unit: '%',
          detail: health[:health_rating],
          higher_is_better: true,
          warning_at: 75,
          critical_at: 60
        },
        {
          label: 'Pool Utilisation',
          value: pool_pct,
          max: 100,
          unit: '%',
          detail: "#{number_to_currency(pool_allocated, precision: 0, unit: '$')} of #{number_to_currency(pool_capacity, precision: 0, unit: '$')}",
          higher_is_better: false,
          warning_at: 90,
          critical_at: 95
        },
        {
          label: 'Investment Health',
          value: (100 - health[:holiday_pct].to_f).round(1),
          max: 100,
          unit: '%',
          detail: "#{health[:total_contracts] - health[:holiday_contracts]} of #{health[:total_contracts]} contracts performing",
          higher_is_better: true,
          warning_at: 75,
          critical_at: 60
        },
        {
          label: 'Conversion Rate',
          value: conversion,
          max: 100,
          unit: '%',
          detail: "#{accepted} accepted of #{submitted} submitted",
          higher_is_better: true,
          warning_at: 50,
          critical_at: 30
        }
      ]
    end

    def build_funnel(apps)
      stages = %w[created user_details property_details income_and_loan_options submitted processing accepted]
      stage_labels = {
        'created' => 'Started',
        'user_details' => 'User details',
        'property_details' => 'Property details',
        'income_and_loan_options' => 'Income & loan',
        'submitted' => 'Submitted',
        'processing' => 'Processing',
        'accepted' => 'Accepted'
      }
      counts = apps.group(:status).count
      rejected = counts['rejected'].to_i

      ever_reached = stages.each_with_index.map do |stage, i|
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
        nodes << { name: 'Rejected', value: rejected, rejected: true }
        links << { source: stages.index('processing'), target: nodes.size - 1, value: rejected }
      end

      { nodes: nodes, links: links, total_started: ever_reached[0] }
    end

    def build_trends(portfolio, apps)
      monthly_apps = portfolio.growth_data(scope: apps, months: 12)
      monthly_pl = portfolio.monthly_pl(months: 12)
      monthly_fum = portfolio.monthly_fum(months: 12)

      {
        applications_monthly: monthly_apps,
        pl_monthly: monthly_pl,
        fum_monthly: monthly_fum
      }
    end
  end
end
