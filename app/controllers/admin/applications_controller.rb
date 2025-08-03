class Admin::ApplicationsController < Admin::BaseController
  before_action :set_application, only: [:show, :edit, :update]

  def index
    @applications = Application.includes(:user).recent
    @applications = @applications.joins(:user).where(
      "applications.address ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?", 
      "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
    ) if params[:search].present?
    @applications = @applications.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @application = Application.new
    @users = User.all.order(:first_name, :last_name)
  end

  def create
    @application = Application.new(application_params)
    
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
    if @application.update(application_params)
      redirect_to admin_application_path(@application), notice: 'Application was successfully updated.'
    else
      @users = User.all.order(:first_name, :last_name)
      render :edit, status: :unprocessable_entity
    end
  end


  private

  def set_application
    @application = Application.find(params[:id])
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
end