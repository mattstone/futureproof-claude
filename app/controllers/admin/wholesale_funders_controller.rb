class Admin::WholesaleFundersController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_wholesale_funder, only: [:show, :edit, :update, :destroy]

  def index
    @wholesale_funders = WholesaleFunder.includes(:funder_pools).recent.page(params[:page]).per(10)
    apply_filters
    prepare_filter_options
  end

  def search
    @wholesale_funders = WholesaleFunder.includes(:funder_pools).recent.page(params[:page]).per(10)
    apply_filters
    prepare_filter_options
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("wholesale-funders-results", partial: "results") }
      format.html { redirect_to admin_wholesale_funders_path(search: params[:search], country: params[:country], currency: params[:currency]) }
    end
  end

  def show
    # Eager load funder_pools for summary calculations
    @wholesale_funder = @wholesale_funder.class.includes(:funder_pools).find(@wholesale_funder.id)
    @wholesale_funder.log_view_by(current_user) if current_user
  end

  def new
    @wholesale_funder = WholesaleFunder.new
  end

  def create
    @wholesale_funder = WholesaleFunder.new(wholesale_funder_params)
    @wholesale_funder.current_user = current_user

    if @wholesale_funder.save
      redirect_to admin_wholesale_funder_path(@wholesale_funder), notice: 'WholesaleFunder was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @wholesale_funder.current_user = current_user
    if @wholesale_funder.update(wholesale_funder_params)
      redirect_to admin_wholesale_funder_path(@wholesale_funder), notice: 'WholesaleFunder was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wholesale_funder.destroy
    redirect_to admin_wholesale_funders_path, notice: 'WholesaleFunder was successfully deleted.'
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:id])
  end

  def wholesale_funder_params
    params.require(:wholesale_funder).permit(:name, :country, :currency)
  end

  def apply_filters
    # Eager load funder_pools for summary calculations
    @wholesale_funders = @wholesale_funders.includes(:funder_pools)
    
    # Search filter
    if params[:search].present?
      search_term = params[:search].to_s.strip
      @wholesale_funders = @wholesale_funders.where(
        "name ILIKE ? OR country ILIKE ?",
        "%#{search_term}%", "%#{search_term}%"
      )
    end

    # Country filter
    if params[:country].present?
      @wholesale_funders = @wholesale_funders.by_country(params[:country])
    end

    # Currency filter
    if params[:currency].present?
      @wholesale_funders = @wholesale_funders.by_currency(params[:currency])
    end
  end

  def prepare_filter_options
    # For filter dropdowns
    @countries = WholesaleFunder.distinct.pluck(:country).compact.sort
    @currencies = %w[AUD USD GBP]
  end
end
