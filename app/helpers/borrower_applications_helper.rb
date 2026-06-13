module BorrowerApplicationsHelper
  # Calculate next income payment details
  def next_income_details(application)
    pending = application.distributions.where(status: [ "pending", "processing" ])
                                       .order(:distribution_date)
                                       .first
    if pending
      {
        date: pending.distribution_date&.to_date,
        amount: pending.amount
      }
    else
      nil
    end
  end

  # Filter distributions by time period
  def filter_distributions_by_period(distributions, period = "all")
    case period
    when "month"
      distributions.where(distribution_date: 1.month.ago..Time.current)
    when "quarter"
      distributions.where(distribution_date: 3.months.ago..Time.current)
    when "year"
      distributions.where(distribution_date: 1.year.ago..Time.current)
    else
      distributions
    end.order(distribution_date: :desc)
  end

  # Calculate period summary for distributions
  def distribution_period_summary(distributions)
    {
      total: distributions.sum(:amount),
      received: distributions.where(status: "completed").sum(:amount),
      pending: distributions.where(status: [ "pending", "processing" ]).sum(:amount),
      count: distributions.count
    }
  end

  # Build complete income summary for display
  def income_summary_for_application(application)
    {
      property_value: application.home_value,
      mortgage_amount: application.equity_investment_amount,
      ltv: application.equity_percentage,
      term_years: application.participation_term_years,
      status: application.status.humanize,
      total_income_received: application.distributions.where(status: "completed").sum(:amount),
      next_income: next_income_details(application),
      remaining_income_payments: application.distributions.where(status: [ "pending", "processing" ]).count
    }
  end

  # Format currency amount (reusable across borrower portal)
  def format_income_currency(amount)
    "$#{number_with_precision(amount || 0, precision: 2)}"
  end

  # Format large currency amounts (whole dollars)
  def format_property_currency(amount)
    "$#{number_with_precision(amount || 0, precision: 0, delimiter: ',')}"
  end

  # Status badge color for distributions
  def distribution_status_badge_class(status)
    case status.to_s
    when "completed"
      "badge-success"
    when "processing"
      "badge-warning"
    when "pending"
      "badge-info"
    when "failed"
      "badge-danger"
    else
      "badge-secondary"
    end
  end
end
