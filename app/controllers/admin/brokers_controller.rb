module Admin
  class BrokersController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_admin!
    before_action :set_broker, only: [:show, :edit, :update, :toggle_active]

    def index
      @brokers = Broker.order(:name)
      @brokers = @brokers.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
      @brokers = @brokers.page(params[:page]).per(20)
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
        redirect_to admin_broker_path(@broker), notice: 'Broker created successfully.'
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
      params.require(:broker).permit(:name, :email, :country, :jurisdiction, :contact_telephone, :contact_telephone_country_code, :password, :password_confirmation)
    end
  end
end
