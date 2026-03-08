module Admin
  class BrokerLendersController < BaseController
    before_action :set_broker
    before_action :set_broker_lender, only: [:toggle_active]

    def available_lenders
      assigned_lender_ids = @broker.lenders.pluck(:id)
      @available_lenders = Lender.where.not(id: assigned_lender_ids).order(:name)
      render json: @available_lenders.map { |l| { id: l.id, name: l.name } }
    end

    def add_lender
      lender = Lender.find(params[:lender_id])
      @broker.brokers_lenders.find_or_create_by(lender_id: lender.id, active: true)
      redirect_to admin_broker_path(@broker), notice: "Lender assigned successfully"
    end

    def remove_lender
      @broker.brokers_lenders.where(lender_id: params[:lender_id]).destroy_all
      redirect_to admin_broker_path(@broker), notice: "Lender removed successfully"
    end

    def toggle_active
      @broker_lender.update(active: !@broker_lender.active)
      redirect_to admin_broker_path(@broker), notice: "Lender assignment #{@broker_lender.active ? 'enabled' : 'disabled'}"
    end

    private

    def set_broker
      @broker = Broker.find(params[:broker_id])
    end

    def set_broker_lender
      @broker_lender = BrokerLender.find(params[:id])
    end
  end
end
