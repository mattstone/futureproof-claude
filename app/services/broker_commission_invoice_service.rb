# Service for generating broker commission invoices
#
# Creates CSV/printable invoices of commissions earned over a period
# Used by brokers to download records and by admins for payout processing
#
# Example:
#   service = BrokerCommissionInvoiceService.new(broker: broker, period_start: 1.month.ago, period_end: Time.current)
#   csv_data = service.to_csv
#
class BrokerCommissionInvoiceService
  def initialize(broker:, period_start:, period_end:)
    @broker = broker
    @period_start = period_start
    @period_end = period_end
  end

  # Generate CSV invoice data
  def to_csv
    CSV.generate do |csv|
      # Header
      csv << ['FutureProof Commission Invoice']
      csv << []
      csv << ["Broker:", @broker.name]
      csv << ["Email:", @broker.email]
      csv << ["Period:", "#{@period_start.strftime('%B %d, %Y')} - #{@period_end.strftime('%B %d, %Y')}"]
      csv << ["Generated:", Time.current.strftime('%B %d, %Y at %l:%M %p')]
      csv << []

      # Column headers
      csv << [
        'Application ID',
        'Applicant',
        'Loan Amount',
        'Commission Rate',
        'Commission Amount',
        'Earned Date',
        'Status'
      ]

      # Commission rows
      commissions_in_period.each do |commission|
        csv << [
          commission.application.id,
          commission.application.user.full_name,
          number_to_currency(commission.application.approved_loan_amount),
          "#{commission.commission_rate}%",
          number_to_currency(commission.commission_amount),
          commission.earned_date&.strftime('%B %d, %Y'),
          commission.status.titleize
        ]
      end

      csv << []

      # Summary
      csv << ['SUMMARY']
      csv << ["Total Commissions (All):", number_to_currency(total_commissions)]
      csv << ["Earned Commissions:", number_to_currency(earned_commissions)]
      csv << ["Pending Commissions:", number_to_currency(pending_commissions)]
      csv << ["Paid Commissions:", number_to_currency(paid_commissions)]
    end
  end

  # Generate printable invoice HTML
  def to_html
    {
      broker: @broker,
      period_start: @period_start,
      period_end: @period_end,
      commissions: commissions_in_period,
      totals: {
        all: total_commissions,
        earned: earned_commissions,
        pending: pending_commissions,
        paid: paid_commissions
      }
    }
  end

  private

  def commissions_in_period
    @commissions_in_period ||= BrokerCommission.for_broker(@broker)
                                               .for_period(@period_start, @period_end)
                                               .includes(:application => :user)
                                               .order(earned_date: :desc)
  end

  def total_commissions
    commissions_in_period.sum(:commission_amount).to_f
  end

  def earned_commissions
    commissions_in_period.where(status: [ 'earned', 'paid' ]).sum(:commission_amount).to_f
  end

  def pending_commissions
    commissions_in_period.where(status: 'pending').sum(:commission_amount).to_f
  end

  def paid_commissions
    commissions_in_period.where(status: 'paid').sum(:commission_amount).to_f
  end

  def number_to_currency(amount)
    ActionController::Base.helpers.number_to_currency(amount)
  end
end
