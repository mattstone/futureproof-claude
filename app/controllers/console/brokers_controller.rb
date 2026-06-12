class Console::BrokersController < Console::ResourceController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_broker, only: [ :show, :edit, :update, :activate, :suspend, :reactivate, :assign_lender, :remove_lender, :toggle_lender, :resend_setup ]

  resource Broker
  searches "brokers.name", "brokers.email"
  sortable name: "brokers.name",
           created: "brokers.created_at"
  default_sort :name, :asc
  filters jurisdiction: ->(scope, value) { scope.where(jurisdiction: value) },
          status: ->(scope, value) { scope.where(status: value) }

  csv_column("Name") { |b| b.name }
  csv_column("Firm") { |b| b.firm_name }
  csv_column("Email") { |b| b.email }
  csv_column("Jurisdiction") { |b| b.jurisdiction }
  csv_column("Phone") { |b| b.phone }
  csv_column("Accreditation") { |b| b.accreditation_ref }
  csv_column("Status") { |b| b.status }

  def show
    @onboarding = Console::PartnerOnboarding.for(@broker)
    @assignments = @broker.broker_lenders.includes(:lender).order("lenders.name")
    @available_lenders = Lender.status_active.where.not(id: @broker.lender_ids).order(:name)
    @applications = @broker.applications.order(created_at: :desc).limit(10)
    @commission_totals = {
      unpaid: BrokerCommission.for_broker(@broker).unpaid.sum(:commission_amount),
      paid: BrokerCommission.for_broker(@broker).paid.sum(:commission_amount)
    }
    @recent_commissions = BrokerCommission.for_broker(@broker).includes(:application).order(earned_date: :desc).limit(10)
    @stats = stats_for(@broker)
  end

  def scorecard
    @scorecards = Broker.includes(:applications, :broker_commissions).order(:name).map { |broker| stats_for(broker) }
  end

  def new
    @broker = Broker.new
  end

  def create
    @broker = Broker.new(broker_params)
    @broker.status = :pending
    # Devise needs a password at create; the broker sets their own via the
    # setup email, so seed an unguessable throwaway.
    @broker.password = SecureRandom.base58(24)

    if @broker.save
      @broker.update(reset_password_token: SecureRandom.urlsafe_base64, reset_password_sent_at: Time.current)
      BrokerMailer.setup_password(@broker, @broker.reset_password_token).deliver_later
      redirect_to console_broker_path(@broker), notice: "Broker created — password setup email sent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @broker.update(broker_params)
      redirect_to console_broker_path(@broker), notice: "Broker updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Pending -> active: the go-live step once accreditation + agreement are done.
  def activate
    @broker.update!(status: :active)
    AuditLog.log_action(user: current_user, action: "partner_activated", resource: @broker,
                        reason: "Broker activated")
    redirect_to console_broker_path(@broker), notice: "#{@broker.name} is live."
  end

  def suspend
    change_status(:suspended)
  end

  def reactivate
    change_status(:active)
  end

  def assign_lender
    lender = Lender.find(params[:lender_id])
    BrokerLender.find_or_create_by(broker: @broker, lender: lender) { |bl| bl.active = true }
    redirect_to console_broker_path(@broker), notice: "Assigned to #{lender.name}."
  end

  def remove_lender
    lender = Lender.find(params[:lender_id])
    BrokerLender.find_by(broker: @broker, lender: lender)&.destroy
    redirect_to console_broker_path(@broker), notice: "Removed from #{lender.name}."
  end

  def toggle_lender
    assignment = @broker.broker_lenders.find_by!(lender_id: params[:lender_id])
    assignment.update!(active: !assignment.active)
    redirect_to console_broker_path(@broker),
                notice: "#{assignment.lender.name} access #{assignment.active? ? 'activated' : 'deactivated'}."
  end

  def resend_setup
    @broker.update(reset_password_token: SecureRandom.urlsafe_base64, reset_password_sent_at: Time.current)
    BrokerMailer.setup_password(@broker, @broker.reset_password_token).deliver_later
    redirect_to console_broker_path(@broker), notice: "Setup email resent to #{@broker.email}."
  end

  protected

  def base_scope
    Broker.all
  end

  # Same audited status flip with a mandatory reason as lenders/funders.
  def change_status(new_status)
    if params[:reason].blank?
      redirect_to console_broker_path(@broker), alert: "A reason is required — it goes in the audit log." and return
    end

    @broker.update!(status: new_status)
    AuditLog.log_action(
      user: current_user,
      action: new_status == :suspended ? "partner_suspended" : "partner_reactivated",
      resource: @broker,
      reason: params[:reason]
    )
    redirect_to console_broker_path(@broker), notice: "#{@broker.name} #{new_status == :suspended ? 'suspended' : 'reactivated'}."
  end

  private

  def set_broker
    @broker = Broker.find(params[:id])
  end

  def broker_params
    params.require(:broker).permit(:name, :firm_name, :email, :jurisdiction, :phone, :accreditation_ref)
  end

  # One source of truth for broker performance — the fleet scorecard and the
  # per-broker page must never disagree.
  def stats_for(broker)
    apps = broker.applications
    submitted = apps.where(status: %w[submitted processing accepted rejected])
    accepted = apps.where(status: "accepted")
    last_referral = apps.maximum(:created_at)

    {
      broker: broker,
      referrals_30d: apps.where("created_at >= ?", 30.days.ago).count,
      referrals_90d: apps.where("created_at >= ?", 90.days.ago).count,
      referrals_365d: apps.where("created_at >= ?", 365.days.ago).count,
      approval_rate: submitted.count.positive? ? (accepted.count.to_f / submitted.count * 100).round(1) : 0,
      avg_age_at_decision: average_age_at_decision(apps),
      commission_earned: broker.broker_commissions.where(status: %w[earned paid]).sum(:commission_amount),
      last_referral_at: last_referral,
      dormant: last_referral.nil? || last_referral < 90.days.ago
    }
  end

  def average_age_at_decision(apps)
    decided = apps.where(status: %w[accepted rejected]).where.not(created_at: nil, updated_at: nil)
    return 0 if decided.empty?

    total = decided.sum { |a| (a.updated_at.to_date - a.created_at.to_date).to_i }
    (total.to_f / decided.count).round(1)
  end
end
