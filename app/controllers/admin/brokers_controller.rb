module Admin
  class BrokersController < BaseController
    before_action :set_broker, only: [:show, :edit, :update, :toggle_active, :destroy]

    def index
      # Filter by current jurisdiction (default: AU)
      @current_jurisdiction = session[:jurisdiction] || "AU"
      @brokers = Broker.by_jurisdiction(@current_jurisdiction).order(created_at: :desc)
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

    def new
      @broker = Broker.new
      @broker.jurisdiction = session[:jurisdiction] || "AU"
    end

    def create
      @broker = Broker.new(broker_params)
      @broker.jurisdiction = session[:jurisdiction] || "AU"
      
      if @broker.save
        redirect_to admin_broker_path(@broker), notice: 'Broker created successfully'
      else
        render :new, status: :unprocessable_entity
      end
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

    def destroy
      @broker.destroy
      redirect_to admin_brokers_path, notice: 'Broker deleted successfully'
    end

    private

    def set_broker
      @broker = Broker.find(params[:id])
    end

    def broker_params
      params.require(:broker).permit(:name, :email, :phone, :password, :password_confirmation, :active, :jurisdiction)
    end
  end
end
