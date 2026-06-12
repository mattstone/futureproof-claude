class Console::BrokersController < Console::ResourceController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_broker, only: [ :show, :edit, :update, :toggle_active, :assign_lender, :remove_lender ]

  resource Broker
  searches "brokers.name", "brokers.email"
  sortable name: "brokers.name",
           created: "brokers.created_at"
  default_sort :name, :asc
  filters jurisdiction: ->(scope, value) { scope.where(jurisdiction: value) },
          active: ->(scope, value) { scope.where(active: value == "true") }

  csv_column("Name") { |b| b.name }
  csv_column("Email") { |b| b.email }
  csv_column("Jurisdiction") { |b| b.jurisdiction }
  csv_column("Phone") { |b| b.phone }
  csv_column("Active") { |b| b.active? ? "yes" : "no" }

  def show
    @onboarding = Console::PartnerOnboarding.for(@broker)
    @lenders = @broker.lenders
    @available_lenders = Lender.where.not(id: @broker.lender_ids).order(:name)
    @applications = @broker.applications.order(created_at: :desc).limit(10)
  end

  def scorecard
    @scorecards = Broker.includes(:applications, :broker_commissions).order(:name).map do |broker|
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
  end

  def new
    @broker = Broker.new
  end

  def create
    @broker = Broker.new(broker_params)
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

  def toggle_active
    @broker.update(active: !@broker.active)
    redirect_to console_broker_path(@broker), notice: "Broker #{@broker.active ? 'activated' : 'deactivated'}."
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

  protected

  def base_scope
    Broker.all
  end

  private

  def set_broker
    @broker = Broker.find(params[:id])
  end

  def broker_params
    params.require(:broker).permit(:name, :email, :jurisdiction, :phone, :active)
  end

  def average_age_at_decision(apps)
    decided = apps.where(status: %w[accepted rejected]).where.not(created_at: nil, updated_at: nil)
    return 0 if decided.empty?

    total = decided.sum { |a| (a.updated_at.to_date - a.created_at.to_date).to_i }
    (total.to_f / decided.count).round(1)
  end
end
