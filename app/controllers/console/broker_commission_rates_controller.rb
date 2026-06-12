class Console::BrokerCommissionRatesController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_lender
  before_action :set_commission_rate, only: [ :edit, :update, :toggle_active ]

  def new
    @commission_rate = @lender.broker_commission_rates.build
    @brokers = Broker.order(:name)
  end

  def create
    @commission_rate = @lender.broker_commission_rates.build(commission_rate_params)
    @commission_rate.active = true if @commission_rate.active.nil?

    if @commission_rate.save
      redirect_to console_lender_path(@lender), notice: "Commission rate created."
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
      redirect_to console_lender_path(@lender), notice: "Commission rate updated."
    else
      @brokers = Broker.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @commission_rate.update(active: !@commission_rate.active)
    redirect_to console_lender_path(@lender), notice: "Commission rate #{@commission_rate.active ? 'activated' : 'deactivated'}."
  end

  private

  def set_lender
    @lender = Lender.find(params[:lender_id])
  end

  def set_commission_rate
    @commission_rate = @lender.broker_commission_rates.find(params[:id])
  end

  def commission_rate_params
    params.require(:broker_commission_rate).permit(:broker_id, :commission_percentage, :payment_trigger, :active)
  end
end
