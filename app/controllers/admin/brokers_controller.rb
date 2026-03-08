module Admin
  class BrokersController < BaseController
    before_action :set_broker, only: [:show, :edit, :update, :toggle_active]

    def index
      @brokers = Broker.all.order(created_at: :desc)
      @stats = {
        total: @brokers.count,
        active: @brokers.where(active: true).count,
        inactive: @brokers.where(active: false).count
      }
    end

    def show
      @lenders = @broker.lenders
      @broker_lenders = @broker.broker_lenders
    end

    def edit
    end

    def update
      if @broker.update(broker_params)
        redirect_to admin_broker_path(@broker), notice: 'Broker updated successfully'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_active
      @broker.update(active: !@broker.active)
      redirect_to admin_brokers_path, notice: "Broker #{@broker.active ? 'activated' : 'deactivated'}"
    end

    private

    def set_broker
      @broker = Broker.find(params[:id])
    end

    def broker_params
      params.require(:broker).permit(:name, :email, :phone, :active)
    end
  end
end
