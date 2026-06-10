class AdminRiskMetricsService
  def initialize(applications_scope: Application.all, contracts_scope: nil)
    @applications = applications_scope
    @contracts = contracts_scope || default_contracts_scope
  end

  def call
    health = portfolio_health
    {
      portfolio_health: health,
      alerts: alerts(health),
      concentration: concentration_risk(health[:total_aum]),
      monitoring: contract_monitoring,
      model: model_context
    }
  end

  def portfolio_health
    total = @contracts.count
    ok = @contracts.where(status: :ok).count
    holiday = @contracts.where(status: :in_holiday).count
    at_risk = @contracts.where(status: :investment_at_risk).count

    active_total = ok + holiday + at_risk
    score = active_total.positive? ? ((ok.to_f / active_total) * 100).round(1) : 100.0

    aum = @contracts.sum(:allocated_amount)
    at_risk_value = @contracts.where(status: :investment_at_risk).sum(:allocated_amount)
    holiday_value = @contracts.where(status: :in_holiday).sum(:allocated_amount)

    {
      total_contracts: total,
      ok_contracts: ok,
      holiday_contracts: holiday,
      at_risk_contracts: at_risk,
      awaiting_contracts: @contracts.where(status: %i[awaiting_funding awaiting_investment]).count,
      complete_contracts: @contracts.where(status: :complete).count,
      health_score: score,
      health_rating: rating_for(score),
      at_risk_value: at_risk_value,
      holiday_value: holiday_value,
      total_aum: aum,
      at_risk_pct: aum.positive? ? (at_risk_value.to_f / aum * 100).round(2) : 0,
      holiday_pct: aum.positive? ? (holiday_value.to_f / aum * 100).round(2) : 0
    }
  end

  def alerts(health = portfolio_health)
    thresholds = EpmModelConfig.risk_thresholds
    list = []

    list.concat(at_risk_alerts(health, thresholds))
    list.concat(holiday_alerts(health, thresholds))
    list << concentration_alert(health, thresholds)
    list << single_exposure_alert(health, thresholds)
    list << high_ltv_alert(thresholds)
    list.compact!
    list << healthy_alert if list.empty?
    list
  end

  def concentration_risk(total_aum = @contracts.sum(:allocated_amount))
    {
      by_region: region_concentration(total_aum),
      by_lender: lender_concentration,
      by_value_band: value_band_distribution,
      by_term: term_distribution
    }
  end

  def contract_monitoring
    maturing_scope = @contracts.where(status: %i[ok in_holiday]).where(end_date: ..12.months.from_now)
    performing = @contracts.where.not(investment_return_rate: nil)

    {
      status_breakdown: @contracts.group(:status).count,
      maturing_soon: maturing_scope.includes(application: :user).order(:end_date).limit(10),
      maturing_count: maturing_scope.count,
      maturing_value: maturing_scope.sum(:allocated_amount),
      at_risk_detail: @contracts.where(status: :investment_at_risk)
                                .includes(application: :user, lender: nil)
                                .order(allocated_amount: :desc)
                                .limit(10),
      avg_return_rate: performing.any? ? (performing.average(:investment_return_rate)&.round(2) || 0) : 0,
      min_return_rate: performing.any? ? (performing.minimum(:investment_return_rate)&.round(2) || 0) : 0,
      max_return_rate: performing.any? ? (performing.maximum(:investment_return_rate)&.round(2) || 0) : 0
    }
  end

  def model_context
    metrics = EpmModelConfig.risk_metrics
    {
      pod_yr30: metrics[:pod_yr30],
      reinsurance_poc: metrics[:reinsurance_poc],
      portfolio_poc_steady_state: metrics[:portfolio_poc_steady_state],
      version: EpmModelConfig.model_version
    }
  end

  private

  def default_contracts_scope
    app_ids = @applications.pluck(:id)
    return Contract.none if app_ids.empty?
    Contract.where(application_id: app_ids)
  end

  def rating_for(score)
    return 'Excellent' if score >= 90
    return 'Good' if score >= 75
    return 'Fair' if score >= 60
    'Needs Attention'
  end

  def at_risk_alerts(health, thresholds)
    pct = health[:at_risk_pct]
    if pct > thresholds[:at_risk_rate_critical] * 100
      [{ severity: :critical, title: 'High At-Risk Rate',
         detail: "#{pct}% of AUM at risk (#{currency(health[:at_risk_value])})",
         action: 'Review at-risk contracts and investment recovery plan' }]
    elsif pct > thresholds[:at_risk_rate_warning] * 100
      [{ severity: :warning, title: 'Elevated At-Risk Exposure',
         detail: "#{pct}% of AUM at risk",
         action: 'Monitor closely and review individual cases' }]
    else
      []
    end
  end

  def holiday_alerts(health, thresholds)
    pct = health[:holiday_pct]
    count = health[:holiday_contracts]
    if pct > thresholds[:holiday_rate_critical] * 100
      [{ severity: :critical, title: 'High Holiday Rate',
         detail: "#{pct}% of AUM in holiday — #{count} contracts",
         action: 'Investment underperformance exceeds model expectations — review immediately' }]
    elsif pct > thresholds[:holiday_rate_warning] * 100
      [{ severity: :warning, title: 'Elevated Holiday Rate',
         detail: "#{pct}% of AUM in holiday — #{count} contracts",
         action: 'Review investment performance triggering holidays' }]
    else
      []
    end
  end

  def concentration_alert(health, thresholds)
    return nil if health[:total_contracts].zero?

    top = @contracts.where.not(lender_id: nil).group(:lender_id).count.max_by { |_, v| v }
    return nil unless top

    pct = top[1].to_f / health[:total_contracts] * 100
    return nil if pct <= thresholds[:concentration_warning] * 100

    name = Lender.find_by(id: top[0])&.name || 'Unknown'
    {
      severity: :warning,
      title: 'Lender Concentration',
      detail: "#{name} holds #{pct.round(0)}% of contracts",
      action: 'Diversify lender relationships'
    }
  end

  def single_exposure_alert(health, thresholds)
    aum = health[:total_aum]
    return nil if aum.zero?

    largest = @contracts.order(allocated_amount: :desc).first
    return nil unless largest && largest.allocated_amount.to_f / aum > thresholds[:single_exposure_warning]

    pct = (largest.allocated_amount.to_f / aum * 100).round(1)
    {
      severity: :warning,
      title: 'Single Exposure',
      detail: "Largest contract is #{pct}% of total AUM (#{currency(largest.allocated_amount)})",
      action: 'Review concentration limits'
    }
  end

  def high_ltv_alert(thresholds)
    threshold_pct = thresholds[:high_ltv_threshold] * 100
    count = @applications.where(status: :accepted).where('equity_percentage > ?', threshold_pct).count
    return nil if count.zero?

    {
      severity: :info,
      title: 'High LTV Contracts',
      detail: "#{count} accepted applications with equity > #{threshold_pct.round(0)}%",
      action: 'Ensure adequate buffer for market downturns'
    }
  end

  def healthy_alert
    {
      severity: :success,
      title: 'Portfolio Healthy',
      detail: 'No risk alerts detected',
      action: 'Continue monitoring'
    }
  end

  def region_concentration(total_aum)
    %w[AU US NZ UK].each_with_object({}) do |region, acc|
      ids = @applications.where(region: region).pluck(:id)
      value = ids.any? ? @contracts.where(application_id: ids).sum(:allocated_amount) : 0
      acc[region] = {
        value: value,
        pct: total_aum.positive? ? (value.to_f / total_aum * 100).round(1) : 0
      }
    end
  end

  def lender_concentration
    @contracts.where.not(lender_id: nil)
              .joins(:lender)
              .group('lenders.name')
              .sum(:allocated_amount)
              .sort_by { |_, v| -v }
              .first(5)
  end

  def value_band_distribution
    {
      'Under $500K' => @applications.where(home_value: 0..499_999).count,
      '$500K - $1M' => @applications.where(home_value: 500_000..999_999).count,
      '$1M - $2M' => @applications.where(home_value: 1_000_000..1_999_999).count,
      '$2M - $5M' => @applications.where(home_value: 2_000_000..4_999_999).count,
      '$5M+' => @applications.where(home_value: 5_000_000..).count
    }
  end

  def term_distribution
    @applications.where.not(investment_term: nil).group(:investment_term).count.sort_by { |k, _| k.to_i }
  end

  def currency(amount)
    ActionController::Base.helpers.number_to_currency(amount, precision: 0)
  end
end
