class Admin::LendersController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_lender, only: [:show, :edit, :update, :destroy]

  def index
    @lenders = Lender.all.order(:lender_type, :name)
  end

  def show
    @lender.log_view_by(current_user) if current_user
  end

  # AJAX endpoint to get available wholesale funders for selection
  def available_wholesale_funders
    @lender = Lender.find(params[:id])
    @available_wholesale_funders = WholesaleFunder.includes(:funder_pools)
                                                  .where.not(id: @lender.wholesale_funders.select(:id))
                                                  .order(:name)
    
    render json: {
      wholesale_funders: @available_wholesale_funders.map do |wf|
        {
          id: wf.id,
          name: wf.name,
          country: wf.country,
          currency: wf.currency,
          currency_symbol: wf.currency_symbol,
          pools_count: wf.funder_pools.count,
          formatted_total_capital: wf.formatted_total_capital
        }
      end
    }
  end

  def new
    @lender = Lender.new
  end

  def create
    @lender = Lender.new(lender_params)
    @lender.current_user = current_user
    
    if @lender.save
      redirect_to admin_lender_path(@lender), notice: 'Lender was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @lender.current_user = current_user
    if @lender.update(lender_params)
      redirect_to admin_lender_path(@lender), notice: 'Lender was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Prevent deletion of Futureproof lender
    if @lender.lender_type_futureproof?
      redirect_to admin_lenders_path, alert: 'Futureproof lender cannot be deleted.'
      return
    end
    
    @lender.destroy
    redirect_to admin_lenders_path, notice: 'Lender was successfully deleted.'
  end

  private

  def set_lender
    @lender = Lender.find(params[:id])
  end

  def lender_params
    params.require(:lender).permit(:lender_type, :name, :address, :postcode, :country, 
                                   :contact_email, :contact_telephone, :contact_telephone_country_code)
  end
end
