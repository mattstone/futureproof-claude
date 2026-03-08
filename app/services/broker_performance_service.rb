class BrokerPerformanceService
  def self.for_lender(lender)
    brokers = lender.brokers
    brokers.map do |broker|
      applications = ::Application.where(lender: lender, broker: broker)
      approved_count = applications.where(application_status: :converted).count
      total_epm_value = applications.joins(:mortgage_contracts)
                                     .where(mortgage_contracts: { status: :active })
                                     .sum("mortgage_contracts.equity_investment_amount") || 0

      {
        broker_name: broker.name,
        broker_id: broker.id,
        total_applications: applications.count,
        approved_count: approved_count,
        pending_count: applications.where(application_status: :open).count,
        rejected_count: applications.where(application_status: 'backoffice_review').count,
        success_rate: applications.count.zero? ? 0 : (approved_count.to_f / applications.count * 100).round(1),
        total_epm_value: total_epm_value
      }
    end.sort_by { |b| b[:total_applications] }.reverse
  end
end
