# Vintage cohort report — contracts grouped by origination quarter, with a
# normalized heatmap. Logic ported verbatim from the legacy admin.
class Console::CohortsController < Console::BaseController
  before_action -> { require_capability(:view_pipeline) }

  def index
    contracts = scoped_contracts.real.where.not(start_date: nil).order(:start_date)

    @cohorts = contracts.group_by { |c| quarter_label(c.start_date) }.map do |label, group|
      count = group.size
      total_allocated = group.sum { |c| c.allocated_amount.to_f }
      pl = group.sum { |c| AdminPortfolioMetricsService.contract_net_pl(c) }
      investment_at_risk = group.count { |c| c.status.to_s == "investment_at_risk" }
      in_holiday = group.count { |c| c.status.to_s == "in_holiday" }

      {
        label: label,
        count: count,
        total_allocated: total_allocated,
        investment_balance: group.sum { |c| c.investment_balance.to_f },
        offset_balance: group.sum { |c| c.offset_balance.to_f },
        investment_at_risk: investment_at_risk,
        in_holiday: in_holiday,
        completed: group.count { |c| c.status.to_s == "complete" },
        pl: pl,
        at_risk_rate: count.positive? ? (investment_at_risk.to_f / count * 100).round(1) : 0,
        holiday_rate: count.positive? ? (in_holiday.to_f / count * 100).round(1) : 0,
        pl_per_contract: count.positive? ? (pl / count).round(0) : 0,
        age_months: ((Date.today - group.first.start_date.to_date).to_i / 30.0).round(0)
      }
    end

    @heatmap = build_heatmap(@cohorts)
  end

  private

  def quarter_label(date)
    "#{date.year} Q#{((date.month - 1) / 3) + 1}"
  end

  def build_heatmap(cohorts)
    return { rows: [], metrics: [] } if cohorts.empty?

    metrics = [
      { key: :holiday_rate, label: "Payment holiday %", polarity: :inverse, format: "percent" },
      { key: :pl_per_contract, label: "P&L / contract", polarity: :direct, format: "currency" },
      { key: :count, label: "Cohort size", polarity: :neutral, format: "integer" },
      { key: :age_months, label: "Age (months)", polarity: :neutral, format: "integer" }
    ]

    ranges = metrics.each_with_object({}) do |metric, acc|
      values = cohorts.map { |c| c[metric[:key]] }
      acc[metric[:key]] = { min: values.min.to_f, max: values.max.to_f }
    end

    rows = cohorts.map do |cohort|
      cells = metrics.map do |metric|
        val = cohort[metric[:key]].to_f
        range = ranges[metric[:key]]
        spread = (range[:max] - range[:min]).abs

        normalized = if spread.zero?
                       0.5
        else
                       raw = (val - range[:min]) / spread
                       metric[:polarity] == :inverse ? raw : (metric[:polarity] == :direct ? 1.0 - raw : 0.5)
        end

        {
          metric: metric[:key],
          label: metric[:label],
          value: cohort[metric[:key]],
          normalized: normalized.round(3),
          polarity: metric[:polarity],
          format: metric[:format]
        }
      end
      { label: cohort[:label], cells: cells }
    end

    { rows: rows, metrics: metrics }
  end
end
