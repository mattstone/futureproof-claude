module Admin
  class BrokerCommissionRatesController < Admin::BaseController
    before_action :authenticate_user!
    before_action :verify_admin!
    before_action :set_lender
    before_action :set_commission_rate, only: [ :edit, :update, :toggle_active, :destroy ]

    def index
      @commission_rates = @lender.broker_commission_rates.includes(:broker).order(created_at: :desc)
      @available_brokers = Broker.where.not(id: @commission_rates.map(&:broker_id))
    end

    def new
      @commission_rate = @lender.broker_commission_rates.build
      @brokers = Broker.order(:name)
    end

    def create
      @commission_rate = @lender.broker_commission_rates.build(commission_rate_params)

      if @commission_rate.save
        redirect_to admin_lender_broker_commission_rates_path(@lender),
                    notice: "Commission rate created successfully."
      else
        @brokers = Broker.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @brokers = Broker.order(:name)
    end

    def update
      if @commission_rate.update(commission_rate_params)
        redirect_to admin_lender_broker_commission_rates_path(@lender),
                    notice: "Commission rate updated successfully."
      else
        @brokers = Broker.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_active
      @commission_rate.update(active: !@commission_rate.active)
      redirect_to admin_lender_broker_commission_rates_path(@lender),
                  notice: "Commission rate #{@commission_rate.active ? 'activated' : 'deactivated'}."
    end

    def destroy
      @commission_rate.destroy
      redirect_to admin_lender_broker_commission_rates_path(@lender),
                  notice: "Commission rate deleted."
    end

    private

    def set_lender
      @lender = Lender.find(params[:lender_id])
    end

    def set_commission_rate
      @commission_rate = BrokerCommissionRate.find(params[:id])
    end

    def verify_admin!
      redirect_to dashboard_path, alert: "Access denied." unless current_user.admin?
    end

    def commission_rate_params
      params.require(:broker_commission_rate).permit(:broker_id, :commission_percentage, :payment_trigger, :active)
    end
  end
end
