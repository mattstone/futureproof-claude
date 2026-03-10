# Service for EPM income calculations and summaries for borrower portal
class BorrowerIncomeService
  def initialize(application)
    @application = application
  end

  # Build complete income summary for borrower dashboard
  def income_summary
    {
      property_value: @application.home_value,
      mortgage_amount: @application.equity_investment_amount,
      ltv: @application.equity_percentage,
      term_years: @application.participation_term_years,
      status: @application.status.humanize,
      total_income_received: total_income_received,
      next_income: next_income_details,
      remaining_income_payments: remaining_payments_count
    }
  end

  # Get next scheduled income payment
  def next_income_details
    pending = @application.distributions.where(status: ["pending", "processing"])
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

  # Get distributions filtered by period
  def distributions_by_period(period = 'all')
    filter_distributions_by_period(period).order(distribution_date: :desc)
  end

  # Calculate summary statistics for a distribution period
  def period_summary(distributions)
    {
      total: distributions.sum(:amount),
      received: distributions.where(status: "completed").sum(:amount),
      pending: distributions.where(status: ["pending", "processing"]).sum(:amount),
      count: distributions.count
    }
  end

  # Get income stats for a specific period
  def period_stats(period = 'all')
    distributions = distributions_by_period(period)
    period_summary(distributions)
  end

  private

  def total_income_received
    @application.distributions.where(status: "completed").sum(:amount)
  end

  def remaining_payments_count
    @application.distributions.where(status: ["pending", "processing"]).count
  end

  def filter_distributions_by_period(period)
    case period.to_s
    when 'month'
      @application.distributions.where(distribution_date: 1.month.ago..Time.current)
    when 'quarter'
      @application.distributions.where(distribution_date: 3.months.ago..Time.current)
    when 'year'
      @application.distributions.where(distribution_date: 1.year.ago..Time.current)
    else
      @application.distributions
    end
  end
end
