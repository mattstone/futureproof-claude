class Admin::MortgagesController < Admin::BaseController
  before_action :set_mortgage, only: [:show, :edit, :update, :destroy]
  before_action :set_audit_history, only: [:show]

  def index
    @mortgages = Mortgage.all.order(:name)
    @mortgages = @mortgages.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @mortgages = @mortgages.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @mortgage = Mortgage.new
  end

  def create
    @mortgage = Mortgage.new(mortgage_params)
    @mortgage.current_user = current_user # Track who created it
    
    if @mortgage.save
      redirect_to admin_mortgage_path(@mortgage), notice: 'Mortgage was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @mortgage.current_user = current_user # Track who updated it
    if @mortgage.update(mortgage_params)
      redirect_to admin_mortgage_path(@mortgage), notice: 'Mortgage was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @mortgage.destroy
    redirect_to admin_mortgages_path, notice: 'Mortgage was successfully deleted.'
  end

  private

  def set_mortgage
    @mortgage = Mortgage.find(params[:id])
  end

  def set_audit_history
    @audit_history = @mortgage.mortgage_versions.includes(:user).recent.limit(50)
  end

  def mortgage_params
    params.require(:mortgage).permit(:name, :mortgage_type, :lvr)
  end
end