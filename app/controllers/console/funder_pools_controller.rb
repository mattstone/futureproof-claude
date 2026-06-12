# Top-level index across all pools; CRUD nested under a wholesale funder.
class Console::FunderPoolsController < Console::BaseController
  before_action -> { require_capability(:manage_partners) }
  before_action :set_wholesale_funder, except: [ :index ]
  before_action :set_funder_pool, only: [ :show, :edit, :update ]

  def index
    scope = FunderPool.includes(:wholesale_funder).recent

    if params[:search].present?
      like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].to_s.strip)}%"
      scope = scope.joins(:wholesale_funder)
                   .where("funder_pools.name ILIKE :like OR wholesale_funders.name ILIKE :like", like: like)
    end
    scope = scope.where(wholesale_funder_id: params[:wholesale_funder_id]) if params[:wholesale_funder_id].present?

    @records = scope.strict_loading.page(params[:page]).per(25)
    @wholesale_funders_for_filter = WholesaleFunder.order(:name)
  end

  def show
    @funder_pool = @wholesale_funder.funder_pools.includes(contracts: { application: :user }).find(params[:id])
    @funder_pool.log_view_by(current_user)
  end

  def new
    @funder_pool = @wholesale_funder.funder_pools.build
  end

  def create
    @funder_pool = @wholesale_funder.funder_pools.build(funder_pool_params)
    @funder_pool.current_user = current_user

    if @funder_pool.save
      redirect_to console_wholesale_funder_path(@wholesale_funder), notice: "Funder pool created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @funder_pool.current_user = current_user

    if @funder_pool.update(funder_pool_params)
      redirect_to console_wholesale_funder_funder_pool_path(@wholesale_funder, @funder_pool), notice: "Funder pool updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_wholesale_funder
    @wholesale_funder = WholesaleFunder.find(params[:wholesale_funder_id])
  end

  def set_funder_pool
    @funder_pool = @wholesale_funder.funder_pools.find(params[:id])
  end

  def funder_pool_params
    params.require(:funder_pool).permit(:name, :amount, :allocated, :benchmark_rate, :margin_rate)
  end
end
