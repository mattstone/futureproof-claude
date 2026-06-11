class Admin::WholesaleFundersController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_wholesale_funder, only: [:show, :edit, :update, :destroy]

  def index
    # Get current jurisdiction from session (synced with top switcher)
    @current_jurisdiction = session[:jurisdiction] || "AU"
    
    # Calculate global statistics (all jurisdictions for context)
    all_funders = WholesaleFunder.includes(:lender_wholesale_funders, :lenders)
    @global_stats = {
      total_allocated: all_funders.sum(:total_allocated_amount),
      total_committed: all_funders.sum { |f| f.committed_amount },
      total_available: all_funders.sum { |f| f.available_amount },
      utilization_pct: calculate_global_utilization(all_funders)
    }
    
    # Get funders for current jurisdiction
    @wholesale_funders = filter_by_jurisdiction(@current_jurisdiction).recent.page(params[:page]).per(10)
    apply_filters
    prepare_filter_options
  end

  def by_jurisdiction
    jurisdiction = params[:jurisdiction].presence || 'All'
    funders = filter_by_jurisdiction(jurisdiction).recent
    
    respond_to do |format|
      format.json do
        data = funders.map do |f|
          {
            id: f.id,
            name: f.name,
            country: f.country,
            currency: f.currency,
            total_allocated: f.total_allocated_amount,
            committed: f.committed_amount,
            available: f.available_amount,
            utilization_pct: f.utilization_percentage,
            runway_months: f.runway_months
          }
        end
        render json: data
      end
    end
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
    params.require(:wholesale_funder).permit(:name, :country, :currency, :total_allocated_amount)
  end

  def filter_by_jurisdiction(jurisdiction)
    if jurisdiction == 'All'
      WholesaleFunder.all
    elsif %w[AU US NZ UK].include?(jurisdiction)
      # Map jurisdiction codes to country names
      country_map = {
        'AU' => 'Australia',
        'US' => 'United States',
        'NZ' => 'New Zealand',
        'UK' => 'United Kingdom'
      }
      WholesaleFunder.by_country(country_map[jurisdiction])
    else
      WholesaleFunder.all
    end
  end

  def calculate_global_utilization(funders)
    total_allocated = funders.sum(:total_allocated_amount)
    return 0 if total_allocated == 0
    total_committed = funders.sum { |f| f.committed_amount }
    ((total_committed.to_f / total_allocated) * 100).round(2)
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
