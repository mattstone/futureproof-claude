class Admin::ApplicationsController < Admin::BaseController
  before_action :set_application, only: [:show, :edit, :update, :send_message, :create_message]
  before_action :set_audit_history, only: [:show]
  before_action :set_messages, only: [:show, :edit]
  before_action :log_view, only: [:show]

  def index
    @applications = Application.includes(:user, :application_messages).recent
    
    # Search filter
    @applications = @applications.joins(:user).where(
      "applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?", 
      "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
    ) if params[:search].present?
    
    # Status filter
    @applications = @applications.where(status: params[:status]) if params[:status].present?
    
    @applications = @applications.page(params[:page]).per(10)
    
    # For the status filter dropdown
    @status_options = Application.statuses.map { |key, value| [key.humanize, key] }
  end

  def show
  end

  def new
    @application = Application.new
    @users = User.all.order(:first_name, :last_name)
  end

  def create
    @application = Application.new(application_params)
    @application.current_user = current_user # Track who created it
    
    if @application.save
      redirect_to admin_application_path(@application), notice: 'Application was successfully created.'
    else
      @users = User.all.order(:first_name, :last_name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.all.order(:first_name, :last_name)
  end

  def update
    @application.current_user = current_user # Track who updated it
    if @application.update(application_params)
      redirect_to admin_application_path(@application), notice: 'Application was successfully updated.'
    else
      @users = User.all.order(:first_name, :last_name)
      @messages = @application.message_threads
      render :edit, status: :unprocessable_entity
    end
  end
  
  def create_message
    @message = @application.application_messages.build(message_params)
    @message.sender = current_user
    @message.message_type = 'admin_to_customer'
    @message.status = 'draft'
    
    # Determine where to redirect based on where the form was submitted from
    redirect_path = params[:from_view] == 'show' ? admin_application_path(@application) : edit_admin_application_path(@application)
    
    if @message.save
      if params[:send_now].present?
        if @message.send_message!
          redirect_to redirect_path, notice: 'Message sent successfully!'
        else
          redirect_to redirect_path, alert: 'Failed to send message.'
        end
      else
        redirect_to redirect_path, notice: 'Message saved as draft!'
      end
    else
      # Handle validation errors by reloading the appropriate view
      if params[:from_view] == 'show'
        @audit_history = @application.application_versions.includes(:user).recent.limit(50)
        @messages = @application.message_threads
        @new_message = @message # Keep the invalid message object for error display
        @ai_agents = AiAgent.active.order(:name)
        @suggested_agent = AiAgent.suggest_for_application(@application)
        render :show, status: :unprocessable_entity
      else
        @users = User.all.order(:first_name, :last_name)
        @messages = @application.message_threads
        @new_message = @message # Keep the invalid message object for error display
        @ai_agents = AiAgent.active.order(:name)
        @suggested_agent = AiAgent.suggest_for_application(@application)
        render :edit, status: :unprocessable_entity
      end
    end
  end
  
  def send_message
    @message = @application.application_messages.find(params[:message_id])
    
    if @message.draft? && @message.send_message!
      redirect_to admin_application_path(@application), notice: 'Message sent successfully!'
    else
      redirect_to admin_application_path(@application), alert: 'Failed to send message.'
    end
  end


  private

  def set_application
    @application = Application.find(params[:id])
  end
  
  def set_audit_history
    @audit_history = @application.application_versions.includes(:user).recent.limit(50)
  end
  
  def set_messages
    @messages = @application.message_threads
    @new_message = @application.application_messages.build
    @ai_agents = AiAgent.active.order(:name)
    # Suggest default agent based on application context
    @suggested_agent = AiAgent.suggest_for_application(@application)
  end
  
  def log_view
    @application.log_view_by(current_user)
  end

  def application_params
    params.require(:application).permit(
      :user_id, 
      :address, 
      :home_value, 
      :ownership_status, 
      :property_state, 
      :has_existing_mortgage, 
      :existing_mortgage_amount,
      :status,
      :rejected_reason
    )
  end
  
  def message_params
    params.require(:application_message).permit(:subject, :content, :parent_message_id, :ai_agent_id)
  end
end