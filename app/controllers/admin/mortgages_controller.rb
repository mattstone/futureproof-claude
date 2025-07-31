class Admin::MortgagesController < Admin::BaseController
  before_action :set_mortgage, only: [:show, :edit, :update, :destroy]

  def index
    @mortgages = Mortgage.all.order(:name)
    @mortgages = @mortgages.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
  end

  def show
  end

  def new
    @mortgage = Mortgage.new
  end

  def create
    @mortgage = Mortgage.new(mortgage_params)
    
    if @mortgage.save
      redirect_to admin_mortgage_path(@mortgage), notice: 'Mortgage was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
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

  def mortgage_params
    params.require(:mortgage).permit(:name, :mortgage_type)
  end
end