class Admin::FundersController < Admin::BaseController
  before_action :set_funder, only: [:show, :edit, :update, :destroy]

  def index
    @funders = Funder.recent.page(params[:page]).per(10)
    apply_filters
    prepare_filter_options
  end

  def search
    @funders = Funder.recent.page(params[:page]).per(10)
    apply_filters
    prepare_filter_options
    
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("funders-results", partial: "results") }
      format.html { redirect_to admin_funders_path(search: params[:search], country: params[:country], currency: params[:currency]) }
    end
  end

  def show
    # Eager load funder_pools for summary calculations
    @funder = @funder.class.includes(:funder_pools).find(@funder.id)
  end

  def new
    @funder = Funder.new
  end

  def create
    @funder = Funder.new(funder_params)

    if @funder.save
      redirect_to admin_funder_path(@funder), notice: 'Funder was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @funder.update(funder_params)
      redirect_to admin_funder_path(@funder), notice: 'Funder was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @funder.destroy
    redirect_to admin_funders_path, notice: 'Funder was successfully deleted.'
  end

  private

  def set_funder
    @funder = Funder.find(params[:id])
  end

  def funder_params
    params.require(:funder).permit(:name, :country, :currency)
  end

  def apply_filters
    # Eager load funder_pools for summary calculations
    @funders = @funders.includes(:funder_pools)
    
    # Search filter
    if params[:search].present?
      search_term = params[:search].to_s.strip
      @funders = @funders.where(
        "name ILIKE ? OR country ILIKE ?",
        "%#{search_term}%", "%#{search_term}%"
      )
    end

    # Country filter
    if params[:country].present?
      @funders = @funders.by_country(params[:country])
    end

    # Currency filter
    if params[:currency].present?
      @funders = @funders.by_currency(params[:currency])
    end
  end

  def prepare_filter_options
    # For filter dropdowns
    @countries = Funder.distinct.pluck(:country).compact.sort
    @currencies = %w[AUD USD GBP]
  end
end
