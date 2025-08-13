class Admin::ContractsController < Admin::BaseController
  before_action :set_contract, only: [:show, :edit, :update, :destroy, :send_message, :create_message]
  before_action :set_messages, only: [:show, :edit]
  before_action :set_ai_agents, only: [:show, :edit, :create_message]

  def index
    @contracts = Contract.includes(application: :user, contract_messages: []).order(created_at: :desc)

    # Search filter
    if params[:search].present?
      @contracts = @contracts.joins(application: :user).where(
        "applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    # Status filter
    @contracts = @contracts.where(status: params[:status]) if params[:status].present?

    @contracts = @contracts.page(params[:page]).per(10)

    # For the status filter dropdown
    @status_options = Contract.statuses.map { |key, value| [key.humanize, key] }

    respond_to do |format|
      format.html # Full page render
      format.turbo_stream # Turbo Frame partial render
    end
  end

  def search
    # Same logic as index but for POST requests via Turbo Stream
    @contracts = Contract.includes(application: :user, contract_messages: []).order(created_at: :desc)

    if params[:search].present?
      @contracts = @contracts.joins(application: :user).where(
        "applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    @contracts = @contracts.where(status: params[:status]) if params[:status].present?
    @contracts = @contracts.page(params[:page]).per(10)
    @status_options = Contract.statuses.map { |key, value| [key.humanize, key] }

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("contracts_results", partial: "results") }
    end
  end

  def show
  end

  def new
    @contract = Contract.new
    @applications = Application.where(status: :accepted).where.not(id: Contract.select(:application_id))
                              .includes(:user).order('users.first_name', 'users.last_name')
  end

  def create
    @contract = Contract.new(contract_params)

    begin
      if @contract.save
        redirect_to admin_contract_path(@contract), notice: 'Contract was successfully created.'
      else
        @applications = Application.where(status: :accepted).where.not(id: Contract.select(:application_id))
                                  .includes(:user).order('users.first_name', 'users.last_name')
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      @contract.errors.add(:application_id, 'already has a contract')
      @applications = Application.where(status: :accepted).where.not(id: Contract.select(:application_id))
                                .includes(:user).order('users.first_name', 'users.last_name')
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @applications = Application.where(status: :accepted).where(
      'applications.id = ? OR applications.id NOT IN (?)', 
      @contract.application_id, 
      Contract.where.not(id: @contract.id).select(:application_id)
    ).includes(:user).order('users.first_name', 'users.last_name')
  end

  def update
    if @contract.update(contract_params)
      redirect_to admin_contract_path(@contract), notice: 'Contract was successfully updated.'
    else
      @applications = Application.where(status: :accepted).where(
        'applications.id = ? OR applications.id NOT IN (?)', 
        @contract.application_id, 
        Contract.where.not(id: @contract.id).select(:application_id)
      ).includes(:user).order('users.first_name', 'users.last_name')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    application_id = @contract.application.id
    @contract.destroy
    redirect_to admin_contracts_path, notice: 'Contract was successfully deleted.'
  end

  def create_message
    @message = @contract.contract_messages.build(message_params)
    @message.sender = current_user
    @message.message_type = 'admin_to_customer'
    @message.status = 'draft'
    
    # Determine redirect path based on where the form was submitted from
    redirect_path = case params[:from_view]
    when 'edit'
      edit_admin_contract_path(@contract)
    else
      admin_contract_path(@contract)
    end

    respond_to do |format|
      if @message.save
        if params[:send_now].present?
          if @message.send_message!
            format.html { redirect_to redirect_path, notice: 'Message sent successfully!' }
            format.turbo_stream { 
              flash.now[:notice] = 'Message sent successfully!'
              set_turbo_stream_variables
              render :message_sent 
            }
          else
            format.html { redirect_to redirect_path, alert: 'Failed to send message.' }
            format.turbo_stream { 
              flash.now[:alert] = 'Failed to send message.'
              render :message_error 
            }
          end
        else
          format.html { redirect_to redirect_path, notice: 'Message saved as draft!' }
          format.turbo_stream { 
            flash.now[:notice] = 'Message saved as draft!'
            set_turbo_stream_variables
            render :message_draft_saved 
          }
        end
      else
        # Re-render the appropriate view with errors
        if params[:from_view] == 'edit'
          @applications = Application.where(status: :accepted).where(
            'applications.id = ? OR applications.id NOT IN (?)', 
            @contract.application_id, 
            Contract.where.not(id: @contract.id).select(:application_id)
          ).includes(:user).order('users.first_name', 'users.last_name')
          
          @messages = @contract.message_threads
          @new_message = @message # Keep the invalid message object for error display
          
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream { render :message_validation_error }
        else
          @messages = @contract.message_threads
          @new_message = @message # Keep the invalid message object for error display
          
          format.html { render :show, status: :unprocessable_entity }
          format.turbo_stream { render :message_validation_error }
        end
      end
    end
  end

  def send_message
    @message = @contract.contract_messages.find(params[:message_id])
    
    respond_to do |format|
      if @message.draft? && @message.send_message!
        format.html { redirect_to admin_contract_path(@contract), notice: 'Message sent successfully!' }
        format.turbo_stream { 
          flash.now[:notice] = 'Message sent successfully!'
          set_turbo_stream_variables
          render :message_sent 
        }
      else
        format.html { redirect_to admin_contract_path(@contract), alert: 'Failed to send message.' }
        format.turbo_stream { 
          flash.now[:alert] = 'Failed to send message.'
          render :message_error 
        }
      end
    end
  end

  private

  def set_contract
    @contract = Contract.find(params[:id])
  end

  def set_messages
    @messages = @contract.message_threads
    @new_message = @contract.contract_messages.build
  end

  def set_ai_agents
    @ai_agents = AiAgent.all
    
    # Set suggested agent based on contract status
    @suggested_agent = case @contract.status
    when 'awaiting_funding'
      @ai_agents.find_by(name: 'Funding Specialist') || @ai_agents.first
    when 'awaiting_investment'
      @ai_agents.find_by(name: 'Investment Advisor') || @ai_agents.first
    when 'in_arrears'
      @ai_agents.find_by(name: 'Support Specialist') || @ai_agents.first
    else
      @ai_agents.find_by(name: 'Customer Success Manager') || @ai_agents.first
    end
  end

  def set_turbo_stream_variables
    @ai_agents = AiAgent.all
    # Set suggested agent based on contract status
    @suggested_agent = case @contract.status
    when 'awaiting_funding'
      @ai_agents.find_by(name: 'Funding Specialist') || @ai_agents.first
    when 'awaiting_investment'
      @ai_agents.find_by(name: 'Investment Advisor') || @ai_agents.first
    when 'in_arrears'
      @ai_agents.find_by(name: 'Support Specialist') || @ai_agents.first
    else
      @ai_agents.find_by(name: 'Customer Success Manager') || @ai_agents.first
    end
  end

  def contract_params
    params.require(:contract).permit(:application_id, :status, :start_date, :end_date)
  end

  def message_params
    params.require(:contract_message).permit(:subject, :content, :parent_message_id, :ai_agent_id)
  end
end