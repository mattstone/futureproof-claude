# The broker commissions ledger: pending → earned → paid. Marking paid is
# the money-moving action, so it requires a reason-free but audited
# confirmation and stamps the paid date.
class Console::BrokerCommissionsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }

  def index
    scope = BrokerCommission.includes(:broker, :application).order(earned_date: :desc, created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.for_broker(Broker.find(params[:broker_id])) if params[:broker_id].present?

    @totals = {
      pending: scope.pending.sum(:commission_amount),
      earned: scope.earned.sum(:commission_amount),
      paid: scope.paid.sum(:commission_amount),
      unpaid: scope.unpaid.sum(:commission_amount)
    }
    @brokers_for_filter = Broker.order(:name)
    @records = scope.page(params[:page]).per(50)
  end

  def mark_paid
    commission = BrokerCommission.find(params[:id])

    if commission.status == "paid"
      redirect_back fallback_location: console_broker_commissions_path, alert: "Already paid." and return
    end

    commission.update!(status: "paid", paid_date: Date.current)
    AuditLog.log_action(
      user: current_user, action: "commission_paid", resource: commission,
      reason: "Commission #{helpers.number_to_currency(commission.commission_amount, precision: 2)} to #{commission.broker.name}",
      notes: "Application ##{commission.application_id}"
    )
    redirect_back fallback_location: console_broker_commissions_path,
                  notice: "Marked paid — #{helpers.number_to_currency(commission.commission_amount, precision: 2)} to #{commission.broker.name}."
  end

  # Pay everything earned for one broker in a single audited run.
  def pay_run
    broker = Broker.find(params[:broker_id])
    commissions = BrokerCommission.for_broker(broker).where(status: %w[pending earned])

    if commissions.none?
      redirect_back fallback_location: console_broker_path(broker), alert: "Nothing unpaid for #{broker.name}." and return
    end

    total = commissions.sum(:commission_amount)
    count = commissions.count
    commissions.update_all(status: "paid", paid_date: Date.current, updated_at: Time.current)

    AuditLog.log_action(
      user: current_user, action: "commission_pay_run", resource: broker,
      reason: "Paid #{count} commission#{'s' unless count == 1} totalling #{helpers.number_to_currency(total, precision: 2)}"
    )
    redirect_back fallback_location: console_broker_path(broker),
                  notice: "Pay run complete — #{count} commission#{'s' unless count == 1}, #{helpers.number_to_currency(total, precision: 2)}."
  end
end
