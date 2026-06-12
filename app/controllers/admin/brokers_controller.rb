module Admin
  class BrokersController < Admin::BaseController
    before_action :authenticate_user!
    before_action :verify_admin!
    before_action :set_broker, only: [:show, :edit, :update, :toggle_active]

    def index
      @brokers = Broker.order(:name)
      @brokers = @brokers.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
      @brokers = @brokers.page(params[:page]).per(20)
    end

    def scorecard
      @scorecards = Broker.includes(:applications, :broker_commissions).order(:name).map do |broker|
        apps = broker.applications
        submitted = apps.where(status: %w[submitted processing accepted rejected])
        accepted = apps.where(status: 'accepted')
        last_referral = apps.maximum(:created_at)

        {
          broker: broker,
          referrals_30d: apps.where('created_at >= ?', 30.days.ago).count,
          referrals_90d: apps.where('created_at >= ?', 90.days.ago).count,
          referrals_365d: apps.where('created_at >= ?', 365.days.ago).count,
          approval_rate: submitted.count.positive? ? (accepted.count.to_f / submitted.count * 100).round(1) : 0,
          avg_age_at_decision: average_age_at_decision(apps),
          commission_earned: broker.broker_commissions.where(status: %w[earned paid]).sum(:commission_amount),
          last_referral_at: last_referral,
          dormant: last_referral.nil? || last_referral < 90.days.ago
        }
      end
    end

    def show
      @lenders = @broker.lenders
      @applications = @broker.applications.order(created_at: :desc).limit(10)
    end

    def new
      @broker = Broker.new
    end

    def create
      @broker = Broker.new(broker_params)
      
      if @broker.save
        # Generate password setup token and send email
        @broker.update(reset_password_token: SecureRandom.urlsafe_base64, reset_password_sent_at: Time.current)
        BrokerMailer.setup_password(@broker, @broker.reset_password_token).deliver_later
        
        redirect_to admin_broker_path(@broker), notice: 'Broker created successfully. Password setup email sent.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @available_lenders = Lender.where.not(id: @broker.lender_ids)
    end

    def update
      if @broker.update(broker_params)
        redirect_to admin_broker_path(@broker), notice: 'Broker updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_active
      @broker.update(active: !@broker.active)
      redirect_to admin_brokers_path, notice: "Broker #{@broker.active ? 'activated' : 'deactivated'} successfully."
    end

    def assign_lender
      @broker = Broker.find(params[:broker_id])
      @lender = Lender.find(params[:lender_id])
      
      BrokerLender.find_or_create_by(broker: @broker, lender: @lender) do |bl|
        bl.active = true
      end
      
      redirect_to edit_admin_broker_path(@broker), notice: "Broker assigned to #{@lender.name}."
    end

    def remove_lender
      @broker = Broker.find(params[:broker_id])
      @lender = Lender.find(params[:lender_id])
      
      BrokerLender.find_by(broker: @broker, lender: @lender)&.destroy
      
      redirect_to edit_admin_broker_path(@broker), notice: "Broker removed from #{@lender.name}."
    end

    private

    def set_broker
      @broker = Broker.find(params[:id])
    end

    def verify_admin!
      redirect_to dashboard_path, alert: 'Access denied.' unless current_user.admin?
    end

    def broker_params
      params.require(:broker).permit(:name, :email, :jurisdiction, :phone, :active, :password, :password_confirmation)
    end

    def average_age_at_decision(apps)
      decided = apps.where(status: %w[accepted rejected]).where.not(created_at: nil, updated_at: nil)
      return 0 if decided.empty?

      total = decided.sum { |a| (a.updated_at.to_date - a.created_at.to_date).to_i }
      (total.to_f / decided.count).round(1)
    end
  end
end
